import 'package:doctruyen/domain/tts/sleep_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 22);

  test('hẹn theo thời gian: còn lại, hết hạn, báo hết hạn một lần', () {
    final s = SleepTimer()..startDuration(const Duration(minutes: 15), t0);
    expect(s.mode, SleepTimerMode.duration);
    expect(
      s.remaining(t0.add(const Duration(minutes: 5))),
      const Duration(minutes: 10),
    );
    expect(
      s.isExpired(t0.add(const Duration(minutes: 14, seconds: 59))),
      isFalse,
    );
    expect(s.consumeExpired(t0.add(const Duration(minutes: 15))), isTrue);
    expect(s.isActive, isFalse);
    expect(s.consumeExpired(t0.add(const Duration(minutes: 16))), isFalse);
  });

  test('giảm âm lượng dần trong cửa sổ cuối', () {
    final s = SleepTimer(fadeWindow: const Duration(seconds: 10))
      ..startDuration(const Duration(minutes: 1), t0);
    expect(s.volumeFactor(t0), 1);
    expect(
      s.volumeFactor(t0.add(const Duration(seconds: 50))),
      closeTo(1, 1e-9),
    );
    expect(
      s.volumeFactor(t0.add(const Duration(seconds: 55))),
      closeTo(0.5, 1e-9),
    );
    expect(s.volumeFactor(t0.add(const Duration(seconds: 60))), 0);
  });

  test('hết chương: dừng đúng một lần khi chương kết thúc', () {
    final s = SleepTimer()..startEndOfChapter();
    expect(s.remaining(t0), isNull);
    expect(s.isExpired(t0), isFalse);
    expect(s.onChapterFinished(), isTrue);
    expect(s.onChapterFinished(), isFalse);
  });

  test(
    'hẹn giờ theo thời gian không dừng khi hết chương; hủy; thời lượng 0',
    () {
      final s = SleepTimer()..startDuration(const Duration(minutes: 30), t0);
      expect(s.onChapterFinished(), isFalse);
      s.cancel();
      expect(s.isActive, isFalse);
      s.startDuration(Duration.zero, t0);
      expect(s.isActive, isFalse);
    },
  );
}
