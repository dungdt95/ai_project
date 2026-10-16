import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/db_constants.dart';
import '../../domain/models/enums.dart';
import '../database/app_database.dart';

/// Truy cập bảng `app_settings` dạng khóa-giá trị (SPEC FR-9.3).
///
/// Cài đặt lưu trong DB thay vì `shared_preferences` để tệp sao lưu JSON mang
/// theo được cả cấu hình — phục hồi là ra đúng trạng thái cũ (SPEC FR-8.5).
class SettingsDao {
  const SettingsDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<Map<String, String>> getAll() async {
    final rows = await _db.query(Tables.appSettings);
    return {
      for (final row in rows)
        row['key']! as String: row['value']! as String,
    };
  }

  Future<String?> get(String key) async {
    final rows = await _db.query(
      Tables.appSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(
      Tables.appSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, int fallback) async {
    final raw = await get(key);
    return raw == null ? fallback : (int.tryParse(raw) ?? fallback);
  }

  Future<void> setInt(String key, int value) => set(key, '$value');

  /// Đơn vị làm tròn mặc định cho hóa đơn mới (SPEC FR-5.7).
  Future<int> roundingUnit() => getInt(
    AppConstants.keyRoundingUnit,
    AppConstants.defaultRoundingUnit,
  );

  Future<void> setRoundingUnit(int unit) =>
      setInt(AppConstants.keyRoundingUnit, unit);

  /// Cách làm tròn mặc định (SPEC FR-5.8).
  Future<RoundingMode> roundingMode() async =>
      RoundingMode.fromDb(await get(AppConstants.keyRoundingMode));

  Future<void> setRoundingMode(RoundingMode mode) =>
      set(AppConstants.keyRoundingMode, mode.dbValue);

  /// `light` | `dark` | `system`.
  Future<String> themeMode() async =>
      await get(AppConstants.keyThemeMode) ?? 'system';

  Future<void> setThemeMode(String mode) =>
      set(AppConstants.keyThemeMode, mode);

  Future<DateTime?> lastBackupAt() async {
    final raw = await get(AppConstants.keyLastBackupAt);
    final ms = raw == null ? null : int.tryParse(raw);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Có đòi xác thực khi mở app hay không (Phase 11).
  Future<bool> appLockEnabled() async =>
      await get(AppConstants.keyAppLock) == 'true';

  Future<void> setAppLockEnabled(bool enabled) =>
      set(AppConstants.keyAppLock, enabled ? 'true' : 'false');

  Future<void> markBackedUp() => setInt(
    AppConstants.keyLastBackupAt,
    DateTime.now().millisecondsSinceEpoch,
  );
}
