import 'package:local_auth/local_auth.dart';

import '../core/constants/app_constants.dart';

/// Xác thực người dùng bằng vân tay, khuôn mặt, hoặc mã khóa máy.
///
/// Tách thành giao diện trừu tượng để test thay được bằng bản giả: thao tác
/// sinh trắc học không chạy được trong widget test, mà phần cần kiểm — *khi
/// nào* đòi xác thực — lại chính là phần dễ sai nhất.
abstract class Authenticator {
  /// Máy có cách nào để xác thực hay không (vân tay, khuôn mặt, hoặc mã khóa).
  Future<bool> isAvailable();

  /// Hiện hộp thoại xác thực. Trả `true` nếu người dùng qua được.
  Future<bool> authenticate();
}

/// Bản thật, dùng `local_auth`.
class DeviceAuthenticator implements Authenticator {
  DeviceAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    // `isDeviceSupported` đúng cả khi máy chỉ có mã PIN mà không có cảm biến
    // vân tay — đó vẫn là một cách khóa hợp lệ.
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở ${AppConstants.appName}',
        // `biometricOnly: false` để máy tự cho dùng mã PIN hoặc hình mở khóa
        // khi vân tay hỏng hoặc tay ướt. Nhờ vậy app **không cần tự quản lý mã
        // PIN dự phòng** — không lưu, không băm, không có gì để lộ.
        biometricOnly: false,
        // **Không** bật `persistAcrossBackgrounding`. Nó tự dựng lại hộp thoại
        // mỗi khi app quay lại tiền cảnh, mà việc đóng hộp thoại cũng đi qua
        // đúng vòng đời đó — nguy cơ thành vòng lặp người dùng không thoát ra
        // được. Để mặc định thì hủy là hủy, và màn khóa còn nút "Mở khóa" để
        // thử lại khi họ muốn.
        persistAcrossBackgrounding: false,
      );
    } on Exception {
      // Người dùng bấm hủy, hoặc máy vừa bị tắt khóa màn hình. Cả hai đều có
      // nghĩa là chưa qua được, không phải lỗi cần báo đỏ.
      return false;
    }
  }
}

/// Quyết định có phải xác thực lại hay không khi app quay lại tiền cảnh.
///
/// Hàm thuần, tách khỏi widget để test được mọi mốc thời gian mà không cần
/// dựng giao diện hay giả lập vòng đời ứng dụng.
bool shouldRelock({
  required bool lockEnabled,
  required DateTime? leftAt,
  required DateTime now,
  Duration grace = AppConstants.appLockGrace,
}) {
  if (!lockEnabled) return false;

  // Chưa từng rời app trong phiên này — tức là app vừa khởi động.
  if (leftAt == null) return true;

  return now.difference(leftAt) >= grace;
}
