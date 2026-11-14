/// Việc cần làm sau khi một câu đọc lỗi.
enum SpeakFailureAction {
  /// Đọc lại đúng câu đó (sau một khoảng nghỉ ngắn).
  retry,

  /// Bỏ cuộc: dừng tại câu hiện tại và báo lỗi — KHÔNG sang câu kế.
  giveUp,
}

/// Chính sách thử lại khi engine TTS báo lỗi — thuần Dart để test được.
///
/// Nguyên tắc: không bao giờ bỏ qua câu chưa được đọc. Lỗi thoáng qua được thử
/// lại cùng câu tối đa [maxRetries] lần; vẫn lỗi thì dừng để người dùng xử lý
/// (ví dụ giọng tiếng Việt đang tải).
class SpeakRetryPolicy {
  SpeakRetryPolicy({
    this.maxRetries = 1,
    this.retryDelay = const Duration(seconds: 1),
  });

  final int maxRetries;
  final Duration retryDelay;

  int _failures = 0;

  /// Số lần lỗi liên tiếp của câu hiện tại.
  int get failures => _failures;

  /// Câu đọc xong bình thường (hoặc đổi sang câu khác): đặt lại bộ đếm.
  void onSuccess() => _failures = 0;

  /// Ghi nhận một lần lỗi và trả về hành động tiếp theo.
  SpeakFailureAction onFailure() {
    _failures++;
    if (_failures > maxRetries) {
      _failures = 0;
      return SpeakFailureAction.giveUp;
    }
    return SpeakFailureAction.retry;
  }

  void reset() => _failures = 0;
}
