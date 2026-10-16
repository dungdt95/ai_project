import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../domain/models/expense_category.dart';
import '../database/app_database.dart';

/// Truy cập bảng `categories` (SPEC FR-9.4).
class CategoryDao {
  const CategoryDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<ExpenseCategory>> getAll() async {
    final rows = await _db.query(
      Tables.categories,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<ExpenseCategory?> getById(String id) async {
    final rows = await _db.query(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ExpenseCategory.fromMap(rows.first);
  }

  Future<void> save(ExpenseCategory category) async {
    await _db.insert(
      Tables.categories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Xóa danh mục. Hóa đơn đang dùng nó được `ON DELETE SET NULL` chuyển về
  /// "chưa phân loại", nên không mất hóa đơn nào.
  ///
  /// Danh mục mặc định (`is_builtin = 1`) không cho xóa.
  Future<void> delete(String id) async {
    await _db.delete(
      Tables.categories,
      where: 'id = ? AND is_builtin = 0',
      whereArgs: [id],
    );
  }

  Future<int> countBills(String categoryId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM ${Tables.bills}
      WHERE category_id = ? AND deleted_at IS NULL
      ''',
      [categoryId],
    );
    return rows.first['cnt']! as int;
  }
}
