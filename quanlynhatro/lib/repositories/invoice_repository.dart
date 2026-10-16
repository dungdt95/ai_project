import '../database/database_helper.dart';
import '../models/invoice.dart';

class InvoiceRepository {
  Future<List<Invoice>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('invoices', orderBy: 'year DESC, month DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getByMonth(int month, int year) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'invoices',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'room_id ASC',
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getByMonthAndRooms(
      int month, int year, List<int> roomIds) async {
    if (roomIds.isEmpty) return [];
    final db = await DatabaseHelper.instance.db;
    final placeholders = roomIds.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM invoices WHERE month = ? AND year = ? AND room_id IN ($placeholders) ORDER BY room_id ASC',
      [month, year, ...roomIds],
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getByRoom(int roomId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'invoices',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'year DESC, month DESC',
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<Invoice?> getByRoomAndMonth(int roomId, int month, int year) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'invoices',
      where: 'room_id = ? AND month = ? AND year = ?',
      whereArgs: [roomId, month, year],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first);
  }

  Future<Invoice?> getPreviousInvoice(int roomId, int month, int year) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'invoices',
      where:
          'room_id = ? AND ((year < ?) OR (year = ? AND month < ?))',
      whereArgs: [roomId, year, year, month],
      orderBy: 'year DESC, month DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first);
  }

  Future<int> insert(Invoice invoice) async {
    final db = await DatabaseHelper.instance.db;
    final map = invoice.toMap()..remove('id');
    return db.insert('invoices', map);
  }

  Future<int> update(Invoice invoice) async {
    final db = await DatabaseHelper.instance.db;
    return db.update('invoices', invoice.toMap(),
        where: 'id = ?', whereArgs: [invoice.id]);
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.db;
    return db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAvailableMonths() async {
    final db = await DatabaseHelper.instance.db;
    return db.rawQuery(
      'SELECT DISTINCT year, month FROM invoices ORDER BY year DESC, month DESC',
    );
  }
}
