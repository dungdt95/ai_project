import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/stats/activity_accumulator.dart';
import '../../domain/stats/stats_aggregator.dart';
import '../database/app_database.dart';

class StatsDao {
  StatsDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Cộng dồn số giây vào (ngày, truyện) — UPDATE rồi INSERT nếu chưa có, vì
  /// SQLite hệ thống trên Android cũ không có UPSERT.
  Future<void> addSeconds(Map<(String, int), PendingSeconds> pending) async {
    if (pending.isEmpty) return;
    await _db.transaction((txn) async {
      for (final e in pending.entries) {
        final (day, bookId) = e.key;
        final p = e.value;
        final exists = await txn.query(
          Tables.books,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [bookId],
        );
        if (exists.isEmpty) continue;
        final n = await txn.rawUpdate(
          'UPDATE reading_stats SET read_seconds = read_seconds + ?, '
          'listen_seconds = listen_seconds + ? WHERE day = ? AND book_id = ?',
          [p.read, p.listen, day, bookId],
        );
        if (n == 0) {
          await txn.insert(Tables.readingStats, {
            'day': day,
            'book_id': bookId,
            'read_seconds': p.read,
            'listen_seconds': p.listen,
          });
        }
      }
    });
  }

  /// Các dòng thống kê từ ngày [fromDay] (yyyy-MM-dd) trở đi.
  Future<List<DailyStat>> since(String fromDay) async {
    final rows = await _db.query(
      Tables.readingStats,
      where: 'day >= ?',
      whereArgs: [fromDay],
    );
    return rows
        .map(
          (r) => DailyStat(
            day: r['day']! as String,
            bookId: r['book_id']! as int,
            readSeconds: r['read_seconds']! as int,
            listenSeconds: r['listen_seconds']! as int,
            chaptersFinished: r['chapters_finished']! as int,
          ),
        )
        .toList();
  }
}
