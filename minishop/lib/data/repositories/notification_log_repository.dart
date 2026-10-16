import '../../core/db/app_database.dart';
import '../models/notification_log.dart';

class NotificationLogRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<int> insert(NotificationLog log) async {
    final db = await _appDb.database;
    return db.insert('notification_logs', log.toMap());
  }

  Future<List<NotificationLog>> getRecent({int limit = 50}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'notification_logs',
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(NotificationLog.fromMap).toList();
  }
}
