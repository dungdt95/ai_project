import 'package:sqflite/sqflite.dart';

/// Nâng cấp lược đồ qua từng phiên bản. Khóa là phiên bản **đích**.
///
/// Quy tắc (như chiahoadon): không DROP cột/bảng; cột mới có DEFAULT; đổi
/// `schema.dart` thì tăng `AppConstants.dbVersion` và thêm bước ở đây.
class Migrations {
  const Migrations._();

  static final Map<int, Future<void> Function(Database db)> steps = {
    // v2: nguồn Google Drive (id thư mục; id tệp, băm, nhãn sửa của chương).
    2: (db) async {
      await db.execute(
        "ALTER TABLE books ADD COLUMN drive_folder_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('ALTER TABLE books ADD COLUMN drive_synced_at INTEGER');
      await db.execute(
        "ALTER TABLE chapters ADD COLUMN drive_file_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE chapters ADD COLUMN content_hash TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE chapters ADD COLUMN drive_modified TEXT NOT NULL DEFAULT ''",
      );
    },
  };

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
