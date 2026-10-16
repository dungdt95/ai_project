import '../database/app_database.dart';
import '../models/borrower.dart';

class BorrowerRepository {
  final _db = AppDatabase();

  Future<List<Borrower>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('borrowers', orderBy: 'name ASC');
    return maps.map(Borrower.fromMap).toList();
  }

  Future<Borrower?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('borrowers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Borrower.fromMap(maps.first);
  }

  Future<int> insert(Borrower b) async {
    final db = await _db.database;
    return db.insert('borrowers', b.toMap());
  }

  Future<void> update(Borrower b) async {
    final db = await _db.database;
    await db.update('borrowers', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('borrowers', where: 'id = ?', whereArgs: [id]);
  }
}
