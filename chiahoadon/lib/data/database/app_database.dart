import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/db_constants.dart';
import 'migrations.dart';
import 'schema.dart';
import 'seed_data.dart';

/// Mở và quản lý kết nối SQLite.
///
/// Toàn app dùng một kết nối duy nhất, mở sẵn lúc khởi động. SQLite tự tuần tự
/// hóa truy cập nên không cần pool, và `sqflite` đã chạy mọi truy vấn trên
/// background isolate nên không chặn luồng UI.
class AppDatabase {
  AppDatabase._(this._db);

  /// Mở DB ở vị trí mặc định của app.
  static Future<AppDatabase> open({String? fileName}) async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, fileName ?? AppConstants.dbFileName);
    return AppDatabase._(await _openAt(path));
  }

  /// Mở DB trong bộ nhớ — dùng cho unit test (PLAN §7, Phase 1).
  static Future<AppDatabase> openInMemory() async =>
      AppDatabase._(await _openAt(inMemoryDatabasePath));

  final Database _db;

  Database get db => _db;

  bool get isOpen => _db.isOpen;

  Future<void> close() => _db.close();

  /// Chạy nhiều thao tác ghi trong một giao dịch.
  ///
  /// Dùng khi lưu hóa đơn: `bills`, `bill_payers`, `bill_participants`,
  /// `bill_items` phải cùng thành công hoặc cùng thất bại, nếu không tổng các
  /// phần sẽ không còn khớp tổng hóa đơn.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      _db.transaction(action);

  /// Xóa toàn bộ dữ liệu người dùng rồi nạp lại dữ liệu khởi tạo (SPEC FR-9.6).
  Future<void> resetAll() async {
    await _db.transaction((txn) async {
      for (final table in Tables.deletionOrder) {
        await txn.delete(table);
      }
      await txn.delete(Tables.appSettings);
    });
    await SeedData.populate(_db);
  }

  static Future<Database> _openAt(String path) => openDatabase(
    path,
    version: AppConstants.dbVersion,
    onConfigure: _onConfigure,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  /// Bật khóa ngoại. SQLite **tắt** tính năng này theo mặc định, và phải bật
  /// trước khi mở giao dịch nào, nên chỉ `onConfigure` là đúng chỗ.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in Schema.createStatements) {
      batch.execute(statement);
    }
    for (final statement in Schema.createIndexes) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);

    await SeedData.populate(db);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) =>
      Migrations.run(db, from, to);
}
