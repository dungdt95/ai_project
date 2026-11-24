import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'leitner.dart';

class ChildProfile {
  final String id;
  final String nickname;
  final String avatarId;
  const ChildProfile({required this.id, required this.nickname, required this.avatarId});

  Map<String, dynamic> toJson() => {'id': id, 'nickname': nickname, 'avatarId': avatarId};
  factory ChildProfile.fromJson(Map m) => ChildProfile(
        id: m['id'] as String,
        nickname: m['nickname'] as String,
        avatarId: (m['avatarId'] ?? 'monkey') as String,
      );
}

/// Khởi tạo Hive và mở các box dùng chung (lưu dạng Map, không cần adapter/codegen).
class Storage {
  static const _profiles = 'profiles';
  static const _progress = 'progress';
  static const _wordStats = 'word_stats';
  static const _settings = 'settings';
  static const _sessions = 'sessions';

  late final Box _profilesBox;
  late final Box _progressBox;
  late final Box _wordStatsBox;
  late final Box _settingsBox;
  late final Box _sessionsBox;

  static Future<Storage> open({String? path}) async {
    // Dùng hive_ce (thuần Dart) + path_provider; tránh hive_ce_flutter vì cần trình biên dịch C khi build.
    Hive.init(path ?? (await getApplicationSupportDirectory()).path);
    final s = Storage();
    s._profilesBox = await Hive.openBox(_profiles);
    s._progressBox = await Hive.openBox(_progress);
    s._wordStatsBox = await Hive.openBox(_wordStats);
    s._settingsBox = await Hive.openBox(_settings);
    s._sessionsBox = await Hive.openBox(_sessions);
    return s;
  }

  // ---- Hồ sơ ----
  List<ChildProfile> profiles() => [
        for (final v in _profilesBox.values) ChildProfile.fromJson(Map.from(v as Map)),
      ];

  Future<ChildProfile> addProfile(String nickname, String avatarId) async {
    final p = ChildProfile(id: DateTime.now().microsecondsSinceEpoch.toString(), nickname: nickname, avatarId: avatarId);
    await _profilesBox.put(p.id, p.toJson());
    return p;
  }

  Future<void> deleteProfile(String id) async {
    await _profilesBox.delete(id);
    final prefix = '$id|';
    for (final box in [_progressBox, _wordStatsBox, _sessionsBox]) {
      final keys = box.keys.where((k) => (k as String).startsWith(prefix)).toList();
      await box.deleteAll(keys);
    }
  }

  // ---- Tiến độ bài học ----
  bool isLessonDone(String profileId, String lessonId) => _progressBox.get('$profileId|$lessonId') != null;

  int starsFor(String profileId, String lessonId) {
    final v = _progressBox.get('$profileId|$lessonId');
    return v == null ? 0 : ((v as Map)['stars'] as num?)?.toInt() ?? 0;
  }

  Future<void> completeLesson(String profileId, String lessonId, {int stars = 3}) {
    final old = starsFor(profileId, lessonId);
    return _progressBox.put('$profileId|$lessonId', {
      'stars': stars > old ? stars : old,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  // ---- Thống kê từ ----
  WordStat? wordStat(String profileId, String wordId) {
    final v = _wordStatsBox.get('$profileId|$wordId');
    return v == null ? null : WordStat.fromJson(Map.from(v as Map));
  }

  Future<void> recordWordAttempt(String profileId, String wordId, {required bool correct, DateTime? now}) {
    final t = now ?? DateTime.now();
    final cur = wordStat(profileId, wordId) ?? WordStat(nextReview: t);
    return _wordStatsBox.put('$profileId|$wordId', cur.update(isCorrect: correct, now: t).toJson());
  }

  // ---- Thời gian chơi ----
  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int secondsPlayed(String profileId, DateTime day) => (_sessionsBox.get('$profileId|${_dayKey(day)}') as num?)?.toInt() ?? 0;

  Future<void> addPlaySeconds(String profileId, int seconds, {DateTime? day}) {
    final d = day ?? DateTime.now();
    return _sessionsBox.put('$profileId|${_dayKey(d)}', secondsPlayed(profileId, d) + seconds);
  }

  Future<void> resetPlaySeconds(String profileId, {DateTime? day}) {
    final d = day ?? DateTime.now();
    return _sessionsBox.put('$profileId|${_dayKey(d)}', 0);
  }

  // ---- Cài đặt ----
  T setting<T>(String key, T fallback) => (_settingsBox.get(key) as T?) ?? fallback;
  Future<void> putSetting(String key, Object value) => _settingsBox.put(key, value);

  /// Version đã cài của từng gói (topicId hoặc tên file → version/timestamp).
  Map<String, int> installedPackVersions() {
    final raw = _settingsBox.get(SettingKeys.installedPackVersions);
    if (raw is! Map) return {};
    return {
      for (final e in Map.from(raw).entries)
        if (e.key is String && e.value is num) e.key as String: (e.value as num).toInt(),
    };
  }

  Future<void> putInstalledPackVersions(Map<String, int> v) =>
      _settingsBox.put(SettingKeys.installedPackVersions, Map<String, int>.from(v));
}

/// Khoá cài đặt.
class SettingKeys {
  static const viHints = 'viHintsEnabled'; // mặc định false
  static const dailyLimitMin = 'dailyLimitMin'; // mặc định 20
  static const musicOn = 'musicOn'; // mặc định true
  static const activeProfile = 'activeProfileId';
  static const autoSyncDrive = 'autoSyncDrive'; // mặc định false
  static const driveFolderId = 'driveFolderId';
  static const lastDriveSyncAt = 'lastDriveSyncAt'; // ISO-8601, có thể null
  static const installedPackVersions = 'installedPackVersions'; // Map<String,int>

  static const defaultDriveFolderId = '10d5w1ZMGNRy4OmdX6_6nnhpaIu1H6hHm';
}
