/// Hằng số dùng chung toàn app.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Chia Hóa Đơn';
  static const String dbFileName = 'chiahoadon.db';
  /// Phiên bản lược đồ. Tăng mỗi khi `schema.dart` đổi, và **luôn** kèm một
  /// bước trong `Migrations.steps` — xem PLAN §4.5 và 13.13.
  static const int dbVersion = 3;

  /// Thư mục con trong app documents dir để lưu ảnh hóa đơn.
  static const String billImageDir = 'bill_images';

  // ─── Làm tròn (SPEC FR-5.7, FR-5.8) ───
  /// Các đơn vị làm tròn cho người dùng chọn, tính bằng đồng.
  static const List<int> roundingUnits = [1, 500, 1000, 5000];
  static const int defaultRoundingUnit = 1000;

  // ─── Giới hạn ───
  /// Số hóa đơn tải mỗi lần khi cuộn danh sách (NFR-3).
  static const int billPageSize = 50;

  /// Chu kỳ tự lưu nháp khi đang nhập hóa đơn (NFR-10).
  static const Duration draftAutoSaveInterval = Duration(seconds: 3);

  /// Thời gian hiện SnackBar cho phép hoàn tác khi xóa.
  static const Duration undoDuration = Duration(seconds: 5);

  /// Nhắc sao lưu nếu quá số ngày này chưa backup (FR-8.6).
  static const int backupReminderDays = 30;

  /// Rời app lâu hơn khoảng này thì phải xác thực lại khi quay vào.
  ///
  /// Không khóa ngay lúc rời app: luồng dùng thật là mở QR rồi nhảy sang app
  /// ngân hàng rồi quay lại — khóa ngay thì lần nào quay lại cũng phải quét
  /// vân tay, và người dùng sẽ tắt hẳn tính năng này.
  static const Duration appLockGrace = Duration(seconds: 30);

  // ─── Khóa trong bảng app_settings ───
  static const String keyRoundingUnit = 'rounding_unit';
  static const String keyRoundingMode = 'rounding_mode';
  static const String keyThemeMode = 'theme_mode';
  static const String keySchemaVersion = 'schema_version';
  static const String keyLastBackupAt = 'last_backup_at';
  static const String keyAppLock = 'app_lock';
}
