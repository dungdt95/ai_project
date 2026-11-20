enum SleepTimerMode { off, duration, endOfChapter }

/// Logic hẹn giờ tắt TTS — thuần Dart, thời gian truyền vào qua tham số.
///
/// - `duration`: dừng khi hết thời gian; âm lượng giảm dần trong [fadeWindow]
///   cuối cùng.
/// - `endOfChapter`: dừng khi chương hiện tại đọc xong (không tự sang chương).
class SleepTimer {
  SleepTimer({this.fadeWindow = const Duration(seconds: 15)});

  final Duration fadeWindow;

  SleepTimerMode _mode = SleepTimerMode.off;
  DateTime? _endAt;

  SleepTimerMode get mode => _mode;
  bool get isActive => _mode != SleepTimerMode.off;
  DateTime? get endAt => _endAt;

  void startDuration(Duration d, DateTime now) {
    if (d <= Duration.zero) {
      cancel();
      return;
    }
    _mode = SleepTimerMode.duration;
    _endAt = now.add(d);
  }

  void startEndOfChapter() {
    _mode = SleepTimerMode.endOfChapter;
    _endAt = null;
  }

  void cancel() {
    _mode = SleepTimerMode.off;
    _endAt = null;
  }

  /// Còn bao lâu (chỉ với chế độ theo thời gian).
  Duration? remaining(DateTime now) {
    final end = _endAt;
    if (_mode != SleepTimerMode.duration || end == null) return null;
    final r = end.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isExpired(DateTime now) {
    final r = remaining(now);
    return r != null && r == Duration.zero;
  }

  /// Hệ số âm lượng 0..1 để giảm dần khi sắp hết giờ.
  double volumeFactor(DateTime now) {
    final r = remaining(now);
    if (r == null || r >= fadeWindow) return 1;
    return (r.inMilliseconds / fadeWindow.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Gọi khi một chương đọc xong. `true` = phải dừng thay vì sang chương sau.
  bool onChapterFinished() {
    if (_mode == SleepTimerMode.endOfChapter) {
      cancel();
      return true;
    }
    return false;
  }

  /// Hết hạn: reset hẹn giờ và báo `true` đúng một lần.
  bool consumeExpired(DateTime now) {
    if (isExpired(now)) {
      cancel();
      return true;
    }
    return false;
  }
}
