import '../../core/db/app_database.dart';
import '../models/category.dart';

class CategoryRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<ProductCategory>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map(ProductCategory.fromMap).toList();
  }

  Future<int> create(ProductCategory category) async {
    final db = await _appDb.database;
    return db.insert('categories', category.toMap());
  }

  Future<int> update(ProductCategory category) async {
    final db = await _appDb.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _appDb.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
