import '../database/database_helper.dart';
import '../models/location.dart';

class LocationRepository {
  Future<List<Location>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('locations', orderBy: 'sort_order ASC, name ASC');
    return rows.map(Location.fromMap).toList();
  }

  Future<Location?> getById(int id) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('locations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Location.fromMap(rows.first);
  }

  Future<int> insert(Location location) async {
    final db = await DatabaseHelper.instance.db;
    final map = location.toMap()..remove('id');
    map['created_at'] = DateTime.now().toIso8601String();
    return db.insert('locations', map);
  }

  Future<int> update(Location location) async {
    final db = await DatabaseHelper.instance.db;
    return db.update('locations', location.toMap(),
        where: 'id = ?', whereArgs: [location.id]);
  }

  Future<bool> hasRooms(int locationId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM rooms WHERE location_id = ?',
      [locationId],
    );
    return ((rows.first['c'] as int?) ?? 0) > 0;
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.db;
    return db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }
}
