import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class SettingsRepository {
  final _db = AppDatabase();

  Future<String?> get(String key) async {
    final db = await _db.database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _db.database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getReminderDays() async {
    final v = await get('due_reminder_days');
    return int.tryParse(v ?? '3') ?? 3;
  }

  Future<String> getTheme() async => (await get('theme')) ?? 'light';

  Future<bool> isPinEnabled() async => (await get('pin_enabled')) == 'true';
}
