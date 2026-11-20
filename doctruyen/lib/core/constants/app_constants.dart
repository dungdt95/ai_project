/// Hằng số dùng chung toàn app.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Đọc Truyện';
  static const String dbFileName = 'doctruyen.db';

  /// Tăng mỗi khi `schema.dart` đổi, kèm một bước trong `Migrations.steps`.
  static const int dbVersion = 2;

  /// Kênh MethodChannel giữa Dart và MainActivity.
  static const String systemChannel = 'com.dtd.doctruyen/system';

  /// Quá thời gian này không chạm màn hình thì ngừng tính giờ đọc.
  static const Duration readingIdleLimit = Duration(minutes: 2);

  /// Độ dài mỗi phần khi tách tệp .txt không có tiêu đề chương.
  static const int txtPartSize = 5000;
}

/// Tên bảng SQLite.
class Tables {
  const Tables._();

  static const String books = 'books';
  static const String arcs = 'arcs';
  static const String chapters = 'chapters';
  static const String bookmarks = 'bookmarks';
  static const String readingStats = 'reading_stats';
}
