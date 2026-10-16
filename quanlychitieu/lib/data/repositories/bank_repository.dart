import '../database/app_database.dart';
import '../models/bank.dart';

class BankRepository {
  final _db = AppDatabase();

  Future<List<Bank>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('banks', orderBy: 'name ASC');
    return maps.map(Bank.fromMap).toList();
  }

  Future<Bank?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('banks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Bank.fromMap(maps.first);
  }

  Future<int> insert(Bank b) async {
    final db = await _db.database;
    return db.insert('banks', b.toMap());
  }

  Future<void> update(Bank b) async {
    final db = await _db.database;
    await db.update('banks', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('banks', where: 'id = ?', whereArgs: [id]);
  }
}
