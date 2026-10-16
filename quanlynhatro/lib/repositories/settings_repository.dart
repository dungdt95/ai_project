import 'package:sqflite/sqflite.dart';
import '../config/constants.dart';
import '../database/database_helper.dart';

class SettingsRepository {
  final Map<String, String> _cache = {};

  Future<String?> get(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value != null) _cache[key] = value;
    return value;
  }

  Future<int> getInt(String key, {int fallback = 0}) async {
    final v = await get(key);
    return int.tryParse(v ?? '') ?? fallback;
  }

  Future<void> set(String key, String value) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cache[key] = value;
  }

  Future<Map<String, String>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('settings');
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key'] as String] = (row['value'] as String?) ?? '';
    }
    _cache
      ..clear()
      ..addAll(map);
    return map;
  }

  Future<int> getElecPrice() =>
      getInt(AppConstants.keyElecPrice, fallback: AppConstants.defaultElecPrice);
  Future<int> getWaterPrice() =>
      getInt(AppConstants.keyWaterPrice, fallback: AppConstants.defaultWaterPrice);
}
