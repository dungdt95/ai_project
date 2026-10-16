import '../../core/db/app_database.dart';
import '../models/notification_app.dart';

class NotificationAppRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<NotificationApp>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query('notification_apps', orderBy: 'label ASC');
    return rows.map(NotificationApp.fromMap).toList();
  }

  Future<List<String>> getEnabledPackageNames() async {
    final db = await _appDb.database;
    final rows = await db.query('notification_apps',
        where: 'enabled = 1', columns: ['package_name']);
    return rows.map((r) => r['package_name'] as String).toList();
  }

  Future<void> update(NotificationApp app) async {
    final db = await _appDb.database;
    await db.update(
      'notification_apps',
      app.toMap(),
      where: 'id = ?',
      whereArgs: [app.id],
    );
  }
}
