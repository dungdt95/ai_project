import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repositories/stats_repository.dart';
import '../domain/stats/activity_accumulator.dart';

/// Đo thời gian đọc/nghe: nhịp 1 giây vào [ActivityAccumulator], ghi xuống DB
/// mỗi 20 giây và khi app xuống nền.
class ActivityTracker with WidgetsBindingObserver {
  ActivityTracker(this._stats, {ActivityAccumulator? accumulator})
    : accumulator = accumulator ?? ActivityAccumulator();

  final StatsRepository _stats;
  final ActivityAccumulator accumulator;
  Timer? _timer;
  int _ticks = 0;

  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    accumulator.tick(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      accumulator.tick(DateTime.now());
      if (++_ticks % 20 == 0) unawaited(flush());
    });
  }

  void readerOpened(int bookId) =>
      accumulator.setReading(bookId, DateTime.now());

  void readerClosed() {
    accumulator.setReading(null, DateTime.now());
    unawaited(flush());
  }

  /// Gọi khi người dùng chạm/cuộn/lật trang.
  void interaction() => accumulator.interaction(DateTime.now());

  Future<void> flush() async {
    accumulator.tick(DateTime.now());
    try {
      await _stats.flush(accumulator);
    } catch (e) {
      debugPrint('Ghi thống kê lỗi: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    accumulator.tick(DateTime.now());
    accumulator.appActive = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) unawaited(flush());
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
