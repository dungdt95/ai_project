import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/vn_text.dart';
import '../../domain/models/item_preset.dart';
import '../database/app_database.dart';

/// Truy cập bảng `item_presets` — danh sách món đặt sẵn tên và giá.
class ItemPresetDao {
  const ItemPresetDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<ItemPreset>> getAll() async {
    final rows = await _db.query(
      Tables.itemPresets,
      orderBy: 'sort_order ASC, name_norm ASC',
    );
    return rows.map(ItemPreset.fromMap).toList();
  }

  Future<ItemPreset?> getById(String id) async {
    final rows = await _db.query(
      Tables.itemPresets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ItemPreset.fromMap(rows.first);
  }

  /// Tìm theo tên, bỏ dấu — gõ "lau thai" ra "Lẩu thái".
  Future<List<ItemPreset>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAll();

    final rows = await _db.query(
      Tables.itemPresets,
      where: 'name_norm LIKE ?',
      whereArgs: ['%${VnText.normalize(trimmed)}%'],
      orderBy: 'sort_order ASC, name_norm ASC',
    );
    return rows.map(ItemPreset.fromMap).toList();
  }

  /// Bản mẫu có cùng tên (đã bỏ dấu), bỏ qua chính [exceptId].
  ///
  /// Dùng để chặn thêm trùng: hai món cùng tên trong bộ chọn thì người dùng
  /// không có cách nào biết nên chọn cái nào.
  Future<ItemPreset?> findByName(String name, {String? exceptId}) async {
    final rows = await _db.query(
      Tables.itemPresets,
      where: exceptId == null
          ? 'name_norm = ?'
          : 'name_norm = ? AND id != ?',
      whereArgs: exceptId == null
          ? [VnText.normalize(name)]
          : [VnText.normalize(name), exceptId],
      limit: 1,
    );
    return rows.isEmpty ? null : ItemPreset.fromMap(rows.first);
  }

  Future<void> save(ItemPreset preset) async {
    await _db.insert(
      Tables.itemPresets,
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Xóa hẳn, không xóa mềm.
  ///
  /// Khác với thành viên: không hóa đơn nào trỏ tới bản mẫu, nên xóa đi không
  /// để lại tham chiếu treo và cũng không làm đổi con số của hóa đơn cũ.
  Future<void> delete(String id) async {
    await _db.delete(Tables.itemPresets, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.itemPresets}',
    );
    return rows.first['cnt']! as int;
  }
}
