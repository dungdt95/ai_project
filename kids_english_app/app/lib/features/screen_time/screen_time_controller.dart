import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

/// Quản lý thời gian sử dụng màn hình (Screen Time).
/// Đếm số phút bé chơi trong ngày, cảnh báo khi còn 2 phút và kích hoạt trạng thái "Momo đi ngủ".
class ScreenTimeController extends Notifier<ScreenTimeState> {
  Timer? _timer;

  @override
  ScreenTimeState build() {
    ref.onDispose(() => _timer?.cancel());
    _startTimer();
    return _calculateCurrentState();
  }

  void _startTimer() {
    _timer?.cancel();
    // Mỗi 15 giây kiểm tra và cộng thời gian
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final profile = ref.read(activeProfileProvider);
      if (profile == null) return;

      final storage = ref.read(storageProvider);
      storage.addPlaySeconds(profile.id, 15);
      state = _calculateCurrentState();
    });
  }

  ScreenTimeState _calculateCurrentState() {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return const ScreenTimeState(playedMinutes: 0, limitMinutes: 20, isTimeUp: false, isWarning: false);
    }

    final storage = ref.read(storageProvider);
    final settings = ref.read(settingsProvider);
    final playedSeconds = storage.secondsPlayed(profile.id, DateTime.now());
    final playedMinutes = (playedSeconds / 60).floor();
    final limitMinutes = settings.dailyLimitMin;

    final isTimeUp = playedMinutes >= limitMinutes;
    final isWarning = !isTimeUp && (limitMinutes - playedMinutes <= 2);

    return ScreenTimeState(
      playedMinutes: playedMinutes,
      limitMinutes: limitMinutes,
      isTimeUp: isTimeUp,
      isWarning: isWarning,
    );
  }

  /// Reset hoặc mở thêm giờ cho hôm nay (gọi từ khu phụ huynh)
  Future<void> grantMoreTime(int extraMinutes) async {
    final storage = ref.read(storageProvider);
    final profile = ref.read(activeProfileProvider);
    if (profile != null) {
      await storage.resetPlaySeconds(profile.id);
    }
    final currentLimit = ref.read(settingsProvider).dailyLimitMin;
    await ref.read(settingsProvider.notifier).setDailyLimit(currentLimit + extraMinutes);
    state = ScreenTimeState(
      playedMinutes: 0,
      limitMinutes: currentLimit + extraMinutes,
      isTimeUp: false,
      isWarning: false,
    );
  }
}

class ScreenTimeState {
  const ScreenTimeState({
    required this.playedMinutes,
    required this.limitMinutes,
    required this.isTimeUp,
    required this.isWarning,
  });

  final int playedMinutes;
  final int limitMinutes;
  final bool isTimeUp;
  final bool isWarning;
}

final screenTimeProvider = NotifierProvider<ScreenTimeController, ScreenTimeState>(ScreenTimeController.new);
