import 'package:sqflite/sqflite.dart';

/// Nâng cấp lược đồ qua từng phiên bản. Khóa là phiên bản **đích**.
///
/// Quy tắc (như chiahoadon): không DROP cột/bảng; cột mới có DEFAULT; đổi
/// `schema.dart` thì tăng `AppConstants.dbVersion` và thêm bước ở đây.
class Migrations {
  const Migrations._();

  static final Map<int, Future<void> Function(Database db)> steps = {};

  static Future<void> run(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      final step = steps[version];
      if (step == null) {
        throw StateError('Thiếu bước nâng cấp DB lên phiên bản $version.');
      }
      await step(db);
    }
  }
}
