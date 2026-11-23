import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/media.dart';
import '../data/content_repository.dart';
import '../data/drive_sync_service.dart';
import '../data/pack_installer.dart';
import '../data/models.dart';
import '../data/storage.dart';

/// Được ghi đè trong main() sau khi mở Hive.
final storageProvider = Provider<Storage>((ref) => throw UnimplementedError('storageProvider chưa được override'));

/// Thư mục chứa các gói đã cài (`<appSupport>/packs`). Được ghi đè trong main().
final packsDirProvider = Provider<Directory>((ref) => throw UnimplementedError('packsDirProvider chưa được override'));

/// Danh sách nguồn nội dung: built-in trước, gói đã cài sau (gói ghi đè chủ đề built-in cùng id).
final contentSourcesProvider = Provider<List<ContentSource>>(
  (ref) => [AssetContentSource(), FileContentSource(ref.watch(packsDirProvider))],
);

final packInstallerProvider = Provider<PackInstaller>((ref) => PackInstaller(ref.watch(packsDirProvider)));

final driveSyncServiceProvider = Provider<DriveSyncService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final storage = ref.read(storageProvider);
  return DriveSyncService(
    auth: GoogleDriveAuth(),
    installer: ref.watch(packInstallerProvider),
    client: client,
    folderId: () => ref.read(settingsProvider).driveFolderId,
    readVersions: storage.installedPackVersions,
    writeVersions: storage.putInstalledPackVersions,
  );
});

/// Chỉ đồng bộ ngầm một lần trong mỗi phiên chạy app.
final driveBackgroundSyncDoneProvider = NotifierProvider<_FlagNotifier, bool>(_FlagNotifier.new);

class _FlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void mark() => state = true;
}


final topicsProvider = FutureProvider<List<Topic>>((ref) => ContentRegistry(ref.watch(contentSourcesProvider)).load());

// ---------------- Cài đặt ----------------
class AppSettings {
  final bool viHints;
  final int dailyLimitMin;
  final bool musicOn;
  final bool autoSyncDrive;
  final String driveFolderId;
  final String? lastDriveSyncAt;
  const AppSettings({
    this.viHints = false,
    this.dailyLimitMin = 60,
    this.musicOn = true,
    this.autoSyncDrive = false,
    this.driveFolderId = SettingKeys.defaultDriveFolderId,
    this.lastDriveSyncAt,
  });

  AppSettings copyWith({
    bool? viHints,
    int? dailyLimitMin,
    bool? musicOn,
    bool? autoSyncDrive,
    String? driveFolderId,
    String? lastDriveSyncAt,
  }) =>
      AppSettings(
        viHints: viHints ?? this.viHints,
        dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin,
        musicOn: musicOn ?? this.musicOn,
        autoSyncDrive: autoSyncDrive ?? this.autoSyncDrive,
        driveFolderId: driveFolderId ?? this.driveFolderId,
        lastDriveSyncAt: lastDriveSyncAt ?? this.lastDriveSyncAt,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final s = ref.read(storageProvider);
    return AppSettings(
      viHints: s.setting(SettingKeys.viHints, false),
      dailyLimitMin: s.setting(SettingKeys.dailyLimitMin, 60),
      musicOn: s.setting(SettingKeys.musicOn, true),
      autoSyncDrive: s.setting(SettingKeys.autoSyncDrive, false),
      driveFolderId: s.setting(SettingKeys.driveFolderId, SettingKeys.defaultDriveFolderId),
      lastDriveSyncAt: s.setting<String?>(SettingKeys.lastDriveSyncAt, null),
    );
  }

  Future<void> setViHints(bool v) async {
    state = state.copyWith(viHints: v);
    await ref.read(storageProvider).putSetting(SettingKeys.viHints, v);
  }

  Future<void> setDailyLimit(int min) async {
    state = state.copyWith(dailyLimitMin: min);
    await ref.read(storageProvider).putSetting(SettingKeys.dailyLimitMin, min);
  }

  Future<void> setMusic(bool v) async {
    state = state.copyWith(musicOn: v);
    await ref.read(storageProvider).putSetting(SettingKeys.musicOn, v);
  }

  Future<void> setAutoSyncDrive(bool v) async {
    state = state.copyWith(autoSyncDrive: v);
    await ref.read(storageProvider).putSetting(SettingKeys.autoSyncDrive, v);
  }

  Future<void> markDriveSynced([DateTime? at]) async {
    final iso = (at ?? DateTime.now()).toIso8601String();
    state = state.copyWith(lastDriveSyncAt: iso);
    await ref.read(storageProvider).putSetting(SettingKeys.lastDriveSyncAt, iso);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------------- Hồ sơ ----------------
class ProfilesNotifier extends Notifier<List<ChildProfile>> {
  @override
  List<ChildProfile> build() => ref.read(storageProvider).profiles();

  Future<ChildProfile> add(String nickname, String avatarId) async {
    final p = await ref.read(storageProvider).addProfile(nickname, avatarId);
    state = ref.read(storageProvider).profiles();
    return p;
  }

  Future<void> remove(String id) async {
    await ref.read(storageProvider).deleteProfile(id);
    state = ref.read(storageProvider).profiles();
    if (ref.read(activeProfileIdProvider) == id) ref.read(activeProfileIdProvider.notifier).set(null);
  }
}

final profilesProvider = NotifierProvider<ProfilesNotifier, List<ChildProfile>>(ProfilesNotifier.new);

class ActiveProfileIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final id = ref.read(storageProvider).setting<String?>(SettingKeys.activeProfile, null);
    return ref.read(storageProvider).profiles().any((p) => p.id == id) ? id : null;
  }

  Future<void> set(String? id) async {
    state = id;
    await ref.read(storageProvider).putSetting(SettingKeys.activeProfile, id ?? '');
  }
}

final activeProfileIdProvider = NotifierProvider<ActiveProfileIdNotifier, String?>(ActiveProfileIdNotifier.new);

final activeProfileProvider = Provider<ChildProfile?>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  for (final p in ref.watch(profilesProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

/// Tăng mỗi khi tiến độ thay đổi để UI vẽ lại.
class ProgressVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final progressVersionProvider = NotifierProvider<ProgressVersion, int>(ProgressVersion.new);

// ---------------- Âm thanh ----------------
final audioProvider = Provider<AudioService>((ref) {
  // Đọc cài đặt tại thời điểm phát → bật/tắt gợi ý tiếng Việt có hiệu lực ngay.
  final svc = AudioService(viHintsEnabled: () => ref.read(settingsProvider).viHints);
  ref.onDispose(svc.dispose);
  return svc;
});
