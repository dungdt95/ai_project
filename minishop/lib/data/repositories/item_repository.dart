import '../../core/db/app_database.dart';
import '../models/item.dart';

class ItemRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<Item>> getAll({bool onlyActive = false}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'items',
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Item.fromMap).toList();
  }

  Future<int> create(Item item) async {
    final db = await _appDb.database;
    return db.insert('items', item.toMap());
  }

  Future<int> update(Item item) async {
    final db = await _appDb.database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _appDb.database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}
