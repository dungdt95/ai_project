import '../database/app_database.dart';
import '../models/category.dart';

class CategoryRepository {
  final _db = AppDatabase();

  Future<List<Category>> getAll({String? type}) async {
    final db = await _db.database;
    final maps = type != null
        ? await db.query('categories', where: 'type = ?', whereArgs: [type])
        : await db.query('categories');
    return maps.map(Category.fromMap).toList();
  }

  Future<Category?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> insert(Category c) async {
    final db = await _db.database;
    return db.insert('categories', c.toMap());
  }

  Future<void> update(Category c) async {
    final db = await _db.database;
    await db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('categories', where: 'id = ? AND is_default = 0', whereArgs: [id]);
  }
}
