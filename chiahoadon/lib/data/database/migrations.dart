import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/vn_text.dart';

/// Nâng cấp lược đồ qua từng phiên bản (PLAN §4.5).
///
/// Quy tắc bắt buộc:
/// - **Không bao giờ** `DROP COLUMN` hay `DROP TABLE` — dữ liệu người dùng là
///   thứ duy nhất không tạo lại được, và app không có bản sao trên cloud.
/// - Cột mới luôn có `DEFAULT`, để bản ghi cũ đọc được ngay mà không cần backfill.
/// - Mỗi phiên bản là một hàm riêng, chạy tuần tự, nên nhảy từ v1 lên v5 vẫn đúng.
/// - **Đổi `schema.dart` thì phải tăng `AppConstants.dbVersion` và thêm một bước
///   ở đây.** Thiếu bước này, máy đã cài bản cũ sẽ giữ nguyên lược đồ cũ và app
///   đổ lỗi ngay khi ghi — xem 13.13.
class Migrations {
  const Migrations._();

  /// Khóa là phiên bản **đích** của bước nâng cấp.
  static final Map<int, Future<void> Function(Database db)> steps = {
    2: _addBillTitleNorm,
    3: _addItemPresets,
  };

  /// Chạy mọi bước từ [from] (không bao gồm) tới [to] (bao gồm).
  static Future<void> run(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      final step = steps[version];
      if (step == null) {
        throw StateError(
          'Thiếu bước nâng cấp DB lên phiên bản $version. '
          'Kiểm tra Migrations.steps.',
        );
      }
      await step(db);
    }
  }

  /// v2 — thêm cột tìm kiếm không dấu cho hóa đơn (SPEC FR-3.12).
  ///
  /// Hóa đơn cũ được điền lại giá trị ngay trong bước này: `title_norm` phải
  /// sinh bằng `VnText.normalize`, mà SQLite không có hàm bỏ dấu tiếng Việt,
  /// nên phải tính bằng Dart rồi ghi ngược xuống.
  static Future<void> _addBillTitleNorm(Database db) async {
    await db.execute(
      "ALTER TABLE ${Tables.bills} ADD COLUMN title_norm TEXT NOT NULL "
      "DEFAULT ''",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bills_title_norm '
      'ON ${Tables.bills}(title_norm)',
    );

    final rows = await db.query(Tables.bills, columns: ['id', 'title']);
    final batch = db.batch();
    for (final row in rows) {
      batch.update(
        Tables.bills,
        {'title_norm': VnText.normalize(row['title']! as String)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// v3 — thêm bảng món đặt sẵn.
  ///
  /// Bảng mới nên không có dữ liệu cũ phải điền lại. `IF NOT EXISTS` để bước
  /// này chạy lại được mà không hỏng, phòng khi nâng cấp bị ngắt giữa chừng.
  static Future<void> _addItemPresets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.itemPresets} (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        name_norm   TEXT    NOT NULL,
        unit_price  INTEGER NOT NULL DEFAULT 0,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_item_presets_norm '
      'ON ${Tables.itemPresets}(name_norm)',
    );
  }
}
