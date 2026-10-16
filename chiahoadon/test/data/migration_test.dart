import 'package:chiahoadon/core/constants/app_constants.dart';
import 'package:chiahoadon/core/constants/db_constants.dart';
import 'package:chiahoadon/data/database/migrations.dart';
import 'package:chiahoadon/data/database/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Test nâng cấp lược đồ (PLAN §4.5).
///
/// Dựng lại **lược đồ v1 thật** rồi chạy migration lên phiên bản hiện tại, đúng
/// như chuyện xảy ra trên máy người dùng đã cài bản cũ. Không có test này thì
/// lỗi chỉ lộ ra khi cài đè lên bản cũ — mà bộ test dùng DB mới tinh nên không
/// bao giờ chạm tới.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  /// Lược đồ `bills` của phiên bản 1 — **chưa có** cột `title_norm`.
  const billsV1 = '''
    CREATE TABLE bills (
      id                TEXT PRIMARY KEY,
      title             TEXT    NOT NULL,
      note              TEXT,
      bill_date         INTEGER NOT NULL,
      category_id       TEXT,
      group_id          TEXT,
      split_type        TEXT    NOT NULL,
      input_mode        TEXT    NOT NULL,
      subtotal          INTEGER NOT NULL DEFAULT 0,
      discount_mode     TEXT    NOT NULL DEFAULT 'none',
      discount_value    INTEGER NOT NULL DEFAULT 0,
      discount_amount   INTEGER NOT NULL DEFAULT 0,
      tax_mode          TEXT    NOT NULL DEFAULT 'none',
      tax_value         INTEGER NOT NULL DEFAULT 0,
      tax_amount        INTEGER NOT NULL DEFAULT 0,
      service_mode      TEXT    NOT NULL DEFAULT 'none',
      service_value     INTEGER NOT NULL DEFAULT 0,
      service_amount    INTEGER NOT NULL DEFAULT 0,
      tip_amount        INTEGER NOT NULL DEFAULT 0,
      surcharge_alloc   TEXT    NOT NULL DEFAULT 'proportional',
      rounding_unit     INTEGER NOT NULL DEFAULT 1000,
      rounding_mode     TEXT    NOT NULL DEFAULT 'up',
      total_exact       INTEGER NOT NULL DEFAULT 0,
      total_amount      INTEGER NOT NULL DEFAULT 0,
      rounding_delta    INTEGER NOT NULL DEFAULT 0,
      status            TEXT    NOT NULL DEFAULT 'draft',
      image_path        TEXT,
      created_at        INTEGER NOT NULL,
      updated_at        INTEGER NOT NULL,
      deleted_at        INTEGER
    )
  ''';

  Future<Database> openV1Database() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.execute(billsV1);

    // Một hóa đơn có dấu tiếng Việt, để kiểm tra phần điền lại dữ liệu.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(Tables.bills, {
      'id': 'bill-cu',
      'title': 'Ăn lẩu tất niên',
      'bill_date': now,
      'split_type': 'equal',
      'input_mode': 'total',
      'total_amount': 900000,
      'status': 'unpaid',
      'created_at': now,
      'updated_at': now,
    });

    return db;
  }

  test('phiên bản hiện tại có đủ bước nâng cấp từ v1', () {
    for (var version = 2; version <= AppConstants.dbVersion; version++) {
      expect(
        Migrations.steps.containsKey(version),
        isTrue,
        reason: 'Thiếu bước nâng cấp lên phiên bản $version',
      );
    }
  });

  test('v1 → v2 thêm cột title_norm và điền lại cho hóa đơn cũ', () async {
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 2);

    final rows = await db.query(Tables.bills);
    expect(rows, hasLength(1));
    expect(
      rows.first['title_norm'],
      'an lau tat nien',
      reason: 'Hóa đơn cũ phải được điền lại chỉ mục tìm kiếm',
    );
  });

  test('sau nâng cấp thì ghi được hóa đơn mới có title_norm', () async {
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 2);

    // Đây chính là câu lệnh đã đổ lỗi trên máy thật trước khi có migration.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(Tables.bills, {
      'id': 'bill-moi',
      'title': 'Cà phê sáng',
      'title_norm': 'ca phe sang',
      'bill_date': now,
      'split_type': 'equal',
      'input_mode': 'total',
      'total_amount': 50000,
      'status': 'unpaid',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final found = await db.query(
      Tables.bills,
      where: 'title_norm LIKE ?',
      whereArgs: ['%ca phe%'],
    );
    expect(found, hasLength(1));
  });

  test('tìm kiếm bỏ dấu hoạt động trên cả hóa đơn cũ lẫn mới', () async {
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 2);

    final found = await db.query(
      Tables.bills,
      where: 'title_norm LIKE ?',
      whereArgs: ['%an lau%'],
    );
    expect(found, hasLength(1));
    expect(found.first['title'], 'Ăn lẩu tất niên');
  });

  test('lược đồ tạo mới đã có sẵn cột, không cần chạy migration', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: AppConstants.dbVersion),
    );
    addTearDown(db.close);

    for (final statement in Schema.createStatements) {
      await db.execute(statement);
    }

    final columns = await db.rawQuery('PRAGMA table_info(${Tables.bills})');
    expect(
      columns.map((row) => row['name']),
      contains('title_norm'),
      reason: 'Máy cài mới phải có cột ngay từ onCreate',
    );
  });

  test('v2 → v3 thêm bảng món đặt sẵn', () async {
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 3);

    // Bảng phải tồn tại và ghi được ngay.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(Tables.itemPresets, {
      'id': 'p1',
      'name': 'Lẩu thái',
      'name_norm': 'lau thai',
      'unit_price': 500000,
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });

    final rows = await db.query(Tables.itemPresets);
    expect(rows, hasLength(1));
    expect(rows.first['unit_price'], 500000);
  });

  test('nâng cấp lên v3 không đụng tới dữ liệu đã có', () async {
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 3);

    final bills = await db.query(Tables.bills);
    expect(bills, hasLength(1));
    expect(bills.first['title'], 'Ăn lẩu tất niên');
    expect(bills.first['total_amount'], 900000);
  });

  test('chạy lại bước v3 hai lần không hỏng', () async {
    // Nâng cấp có thể bị ngắt giữa chừng rồi chạy lại từ đầu.
    final db = await openV1Database();
    addTearDown(db.close);

    await Migrations.run(db, 1, 3);
    await Migrations.run(db, 2, 3);

    expect(await db.query(Tables.itemPresets), isEmpty);
  });

  test('máy cài mới đã có bảng món đặt sẵn ngay từ onCreate', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: AppConstants.dbVersion),
    );
    addTearDown(db.close);

    for (final statement in Schema.createStatements) {
      await db.execute(statement);
    }
    for (final statement in Schema.createIndexes) {
      await db.execute(statement);
    }

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      tables.map((row) => row['name']),
      contains(Tables.itemPresets),
    );
  });
}
