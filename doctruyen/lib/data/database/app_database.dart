import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import 'migrations.dart';
import 'schema.dart';

/// Mở và quản lý kết nối SQLite duy nhất của app.
class AppDatabase {
  AppDatabase._(this._db);

  static Future<AppDatabase> open({String? fileName}) async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, fileName ?? AppConstants.dbFileName);
    return AppDatabase._(await _openAt(path));
  }

  /// DB trong bộ nhớ — dùng cho unit test.
  static Future<AppDatabase> openInMemory() async =>
      AppDatabase._(await _openAt(inMemoryDatabasePath));

  final Database _db;

  Database get db => _db;

  Future<void> close() => _db.close();

  static Future<Database> _openAt(String path) => openDatabase(
    path,
    version: AppConstants.dbVersion,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      final batch = db.batch();
      Schema.createStatements.forEach(batch.execute);
      Schema.createIndexes.forEach(batch.execute);
      await batch.commit(noResult: true);
    },
    onUpgrade: Migrations.run,
  );
}
