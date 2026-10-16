import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/db_constants.dart';
import '../../core/utils/avatar_color.dart';
import '../../core/utils/vn_text.dart';
import '../../domain/models/enums.dart';

/// Dữ liệu khởi tạo khi tạo DB lần đầu (PLAN §4.3).
///
/// Mục tiêu: mở app lần đầu là dùng được ngay — đã có danh mục và đã có bản
/// ghi "Tôi", nên người dùng tạo được hóa đơn mà không phải cấu hình gì trước.
class SeedData {
  const SeedData._();

  static const Uuid _uuid = Uuid();

  /// Tên bản ghi thành viên đại diện chính người dùng (SPEC FR-1.6).
  static const String selfMemberName = 'Tôi';

  /// Bảy danh mục mặc định, kèm emoji và màu.
  static const List<({String name, String icon, int color})> categories = [
    (name: 'Ăn uống', icon: '🍜', color: 0xFFEA580C),
    (name: 'Du lịch', icon: '✈️', color: 0xFF0891B2),
    (name: 'Nhà cửa', icon: '🏠', color: 0xFF0D9488),
    (name: 'Đi lại', icon: '🚕', color: 0xFFCA8A04),
    (name: 'Giải trí', icon: '🎮', color: 0xFF7C3AED),
    (name: 'Mua sắm', icon: '🛒', color: 0xFFDB2777),
    (name: 'Khác', icon: '📦', color: 0xFF6B7280),
  ];

  static Future<void> populate(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      batch.insert(Tables.categories, {
        'id': _uuid.v4(),
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'sort_order': i,
        'is_builtin': 1,
      });
    }

    batch.insert(Tables.members, {
      'id': _uuid.v4(),
      'name': selfMemberName,
      'name_norm': VnText.normalize(selfMemberName),
      'nickname': null,
      'phone': null,
      'bank_name': null,
      'bank_bin': null,
      'bank_account': null,
      'bank_holder': null,
      'avatar_color': AvatarColor.toStored(selfMemberName),
      'note': null,
      'is_self': 1,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });

    final defaults = <String, String>{
      AppConstants.keyRoundingUnit: '${AppConstants.defaultRoundingUnit}',
      AppConstants.keyRoundingMode: RoundingMode.up.dbValue,
      AppConstants.keyThemeMode: 'system',
      AppConstants.keySchemaVersion: '${AppConstants.dbVersion}',
    };
    for (final entry in defaults.entries) {
      batch.insert(Tables.appSettings, {
        'key': entry.key,
        'value': entry.value,
      });
    }

    await batch.commit(noResult: true);
  }
}
