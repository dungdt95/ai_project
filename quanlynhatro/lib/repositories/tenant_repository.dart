import '../database/database_helper.dart';
import '../models/tenant.dart';

class TenantRepository {
  Future<List<Tenant>> getAll({bool currentOnly = false}) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'tenants',
      where: currentOnly ? 'is_current = 1' : null,
      orderBy: 'is_current DESC, contract_start DESC',
    );
    return rows.map(Tenant.fromMap).toList();
  }

  Future<Tenant?> getCurrentByRoom(int roomId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'tenants',
      where: 'room_id = ? AND is_current = 1',
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Tenant.fromMap(rows.first);
  }

  Future<List<Tenant>> getByRoom(int roomId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'tenants',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'is_current DESC, contract_start DESC',
    );
    return rows.map(Tenant.fromMap).toList();
  }

  Future<int> insert(Tenant tenant) async {
    final db = await DatabaseHelper.instance.db;
    final map = tenant.toMap()..remove('id');
    return db.insert('tenants', map);
  }

  Future<int> update(Tenant tenant) async {
    final db = await DatabaseHelper.instance.db;
    return db.update('tenants', tenant.toMap(),
        where: 'id = ?', whereArgs: [tenant.id]);
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.db;
    return db.delete('tenants', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markPreviousAsLeft(int roomId) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('tenants', {'is_current': 0},
        where: 'room_id = ? AND is_current = 1', whereArgs: [roomId]);
  }
}
