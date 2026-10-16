import '../database/app_database.dart';
import '../models/calendar_note.dart';

class CalendarNoteRepository {
  final _db = AppDatabase();

  Future<List<CalendarNote>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('calendar_notes', orderBy: 'date DESC');
    return maps.map(CalendarNote.fromMap).toList();
  }

  Future<List<CalendarNote>> getByMonth(int year, int month) async {
    final db = await _db.database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'calendar_notes',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
    return maps.map(CalendarNote.fromMap).toList();
  }

  Future<List<CalendarNote>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query(
      'calendar_notes',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );
    return maps.map(CalendarNote.fromMap).toList();
  }

  Future<int> insert(CalendarNote note) async {
    final db = await _db.database;
    return db.insert('calendar_notes', note.toMap());
  }

  Future<void> update(CalendarNote note) async {
    final db = await _db.database;
    await db.update('calendar_notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('calendar_notes', where: 'id = ?', whereArgs: [id]);
  }
}
