import 'package:hive_flutter/hive_flutter.dart';

/// Tracks the daily puzzle streak.
class DailyStreakService {
  DailyStreakService._();
  static final DailyStreakService instance = DailyStreakService._();

  static const _boxName = 'sudoku_streak';
  static const _kLastDate = 'lastDate';
  static const _kCurrent = 'current';
  static const _kLongest = 'longest';

  late Box _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  int get currentStreak => _box.get(_kCurrent, defaultValue: 0) as int;
  int get longestStreak => _box.get(_kLongest, defaultValue: 0) as int;
  String? get lastDailyDate => _box.get(_kLastDate) as String?;

  /// Call this when a daily puzzle is completed. Updates the streak.
  Future<void> onDailyCompleted(DateTime date) async {
    final today = _fmt(date);
    final last = lastDailyDate;

    int current;
    if (last == null) {
      current = 1;
    } else if (last == today) {
      return; // already counted today
    } else if (_isYesterday(last, today)) {
      current = currentStreak + 1;
    } else {
      current = 1; // streak broken
    }

    await _box.put(_kLastDate, today);
    await _box.put(_kCurrent, current);
    final longest = longestStreak;
    if (current > longest) await _box.put(_kLongest, current);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isYesterday(String last, String today) {
    try {
      final l = DateTime.parse(last);
      final t = DateTime.parse(today);
      return t.difference(l).inDays == 1;
    } catch (_) {
      return false;
    }
  }
}
