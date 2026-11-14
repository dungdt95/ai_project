import 'package:doctruyen/domain/tts/speak_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lỗi đầu tiên: thử lại cùng câu', () {
    final p = SpeakRetryPolicy();
    expect(p.onFailure(), SpeakFailureAction.retry);
  });

  test('lỗi lần hai liên tiếp: bỏ cuộc (dừng, không sang câu kế)', () {
    final p = SpeakRetryPolicy();
    expect(p.onFailure(), SpeakFailureAction.retry);
    expect(p.onFailure(), SpeakFailureAction.giveUp);
  });

  test('thành công đặt lại bộ đếm', () {
    final p = SpeakRetryPolicy();
    expect(p.onFailure(), SpeakFailureAction.retry);
    p.onSuccess();
    expect(p.failures, 0);
    expect(p.onFailure(), SpeakFailureAction.retry);
  });

  test('sau khi bỏ cuộc, lần phát lại bắt đầu sạch', () {
    final p = SpeakRetryPolicy();
    p.onFailure();
    expect(p.onFailure(), SpeakFailureAction.giveUp);
    expect(p.onFailure(), SpeakFailureAction.retry);
  });

  test('maxRetries = 0: lỗi là dừng ngay', () {
    final p = SpeakRetryPolicy(maxRetries: 0);
    expect(p.onFailure(), SpeakFailureAction.giveUp);
  });

  test('maxRetries tuỳ chỉnh', () {
    final p = SpeakRetryPolicy(maxRetries: 3);
    for (var i = 0; i < 3; i++) {
      expect(p.onFailure(), SpeakFailureAction.retry);
    }
    expect(p.onFailure(), SpeakFailureAction.giveUp);
  });
}
