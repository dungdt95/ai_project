import '../database/database_helper.dart';
import '../models/room.dart';

class RoomRepository {
  Future<List<Room>> getAll({int? locationId}) async {
    final db = await DatabaseHelper.instance.db;
    final rows = locationId != null
        ? await db.query('rooms',
            where: 'location_id = ?',
            whereArgs: [locationId],
            orderBy: 'room_number ASC')
        : await db.query('rooms', orderBy: 'room_number ASC');
    return rows.map(Room.fromMap).toList();
  }

  Future<List<int>> getIdsByLocation(int locationId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('rooms',
        columns: ['id'],
        where: 'location_id = ?',
        whereArgs: [locationId]);
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<Room?> getById(int id) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('rooms', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Room.fromMap(rows.first);
  }

  Future<int> insert(Room room) async {
    final db = await DatabaseHelper.instance.db;
    final map = room.toMap()..remove('id');
    return db.insert('rooms', map);
  }

  Future<int> update(Room room) async {
    final db = await DatabaseHelper.instance.db;
    return db.update('rooms', room.toMap(),
        where: 'id = ?', whereArgs: [room.id]);
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.db;
    await db.delete('tenants', where: 'room_id = ?', whereArgs: [id]);
    await db.delete('invoices', where: 'room_id = ?', whereArgs: [id]);
    return db.delete('rooms', where: 'id = ?', whereArgs: [id]);
  }
}
