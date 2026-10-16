import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../domain/models/member.dart';
import '../database/app_database.dart';

/// Truy cập bảng `members` (SPEC FR-1).
class MemberDao {
  const MemberDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Danh sách thành viên chưa bị xóa, sắp theo tên đã bỏ dấu.
  ///
  /// [includeInactive] = `true` khi hiển thị trang quản lý thành viên;
  /// `false` khi chọn người tham gia hóa đơn mới (SPEC FR-1.5).
  Future<List<Member>> getAll({bool includeInactive = false}) async {
    final rows = await _db.query(
      Tables.members,
      where: includeInactive
          ? 'deleted_at IS NULL'
          : 'deleted_at IS NULL AND is_active = 1',
      orderBy: 'is_self DESC, name_norm ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<Member?> getById(String id) async {
    final rows = await _db.query(
      Tables.members,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Member.fromMap(rows.first);
  }

  /// Nhiều thành viên theo danh sách id, giữ được cả bản ghi đã ngừng hoạt động
  /// để hóa đơn cũ vẫn hiển thị đủ người.
  Future<List<Member>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.query(
      Tables.members,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return rows.map(Member.fromMap).toList();
  }

  /// Bản ghi đại diện chính người dùng (SPEC FR-1.6).
  Future<Member?> getSelf() async {
    final rows = await _db.query(
      Tables.members,
      where: 'is_self = 1 AND deleted_at IS NULL',
      limit: 1,
    );
    return rows.isEmpty ? null : Member.fromMap(rows.first);
  }

  /// Tìm theo tên hoặc biệt danh, bỏ qua dấu và hoa thường (SPEC FR-1.7).
  ///
  /// [normalizedQuery] phải là chuỗi đã qua `VnText.normalize`.
  Future<List<Member>> search(String normalizedQuery) async {
    if (normalizedQuery.isEmpty) return getAll();

    final rows = await _db.query(
      Tables.members,
      where: 'deleted_at IS NULL AND name_norm LIKE ?',
      whereArgs: ['%$normalizedQuery%'],
      orderBy: 'is_self DESC, name_norm ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  /// Các thành viên có tên trùng (sau khi bỏ dấu), dùng để cảnh báo khi thêm mới.
  ///
  /// [excludeId] để khi sửa, bản ghi đang sửa không tự coi là trùng chính nó.
  Future<List<Member>> findByNameNorm(
    String nameNorm, {
    String? excludeId,
  }) async {
    final rows = await _db.query(
      Tables.members,
      where: excludeId == null
          ? 'name_norm = ? AND deleted_at IS NULL'
          : 'name_norm = ? AND deleted_at IS NULL AND id != ?',
      whereArgs: excludeId == null ? [nameNorm] : [nameNorm, excludeId],
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<void> insert(Member member) async {
    await _db.insert(Tables.members, member.toMap());
  }

  Future<void> insertAll(List<Member> members) async {
    if (members.isEmpty) return;

    final batch = _db.batch();
    for (final member in members) {
      batch.insert(Tables.members, member.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(Member member) async {
    await _db.update(
      Tables.members,
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  /// Bật/tắt trạng thái hoạt động — thay cho xóa cứng (SPEC FR-1.5).
  Future<void> setActive(String id, bool isActive) async {
    await _db.update(
      Tables.members,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Chuyển "Tôi" sang thành viên khác.
  ///
  /// Phải bỏ đánh dấu cũ **trước** khi đánh dấu mới trong cùng một giao dịch:
  /// chỉ mục `idx_members_self` là unique partial index nên hai bản ghi cùng
  /// `is_self = 1`, dù chỉ trong khoảnh khắc, sẽ làm câu lệnh thất bại.
  Future<void> setSelf(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.update(
        Tables.members,
        {'is_self': 0, 'updated_at': now},
        where: 'is_self = 1',
      );
      await txn.update(
        Tables.members,
        {'is_self': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Soft delete. Chỉ dùng cho thành viên chưa xuất hiện trong hóa đơn nào;
  /// trường hợp còn lại gọi [setActive] với `false`.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      Tables.members,
      {'deleted_at': now, 'is_active': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Thành viên này đã tham gia, đã ứng tiền, hay đã chuyển tiền chưa.
  ///
  /// Quyết định được phép xóa cứng hay chỉ ngừng hoạt động (SPEC FR-1.5).
  Future<bool> hasAnyReference(String memberId) async {
    final result = await _db.rawQuery(
      '''
      SELECT EXISTS(
        SELECT 1 FROM ${Tables.billParticipants} WHERE member_id = ?
        UNION ALL
        SELECT 1 FROM ${Tables.billPayers}       WHERE member_id = ?
        UNION ALL
        SELECT 1 FROM ${Tables.payments}
          WHERE from_member_id = ? OR to_member_id = ?
        UNION ALL
        SELECT 1 FROM ${Tables.groupMembers}     WHERE member_id = ?
      ) AS has_ref
      ''',
      [memberId, memberId, memberId, memberId, memberId],
    );
    return (result.first['has_ref']! as int) == 1;
  }

  /// Số hóa đơn mà thành viên này có tham gia — hiện trong hộp thoại xác nhận xóa.
  Future<int> countBills(String memberId) async {
    final result = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT bp.bill_id) AS cnt
      FROM ${Tables.billParticipants} bp
      JOIN ${Tables.bills} b ON b.id = bp.bill_id
      WHERE bp.member_id = ? AND b.deleted_at IS NULL
      ''',
      [memberId],
    );
    return result.first['cnt']! as int;
  }
}
