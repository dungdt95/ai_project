import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../domain/models/member_group.dart';
import '../database/app_database.dart';

/// Truy cập bảng `member_groups` và bảng nối `group_members` (SPEC FR-2).
class GroupDao {
  const GroupDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Danh sách nhóm kèm đủ thành viên của từng nhóm.
  ///
  /// Đọc hai truy vấn rồi gộp trong bộ nhớ, thay vì JOIN và gom dòng — số nhóm
  /// luôn nhỏ (hàng chục), nên cách này đơn giản hơn mà không chậm hơn.
  Future<List<MemberGroup>> getAll() async {
    final groupRows = await _db.query(
      Tables.memberGroups,
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    if (groupRows.isEmpty) return const [];

    final linkRows = await _db.query(Tables.groupMembers);
    final byGroup = <String, List<String>>{};
    for (final row in linkRows) {
      final groupId = row['group_id']! as String;
      final memberId = row['member_id']! as String;
      byGroup.putIfAbsent(groupId, () => []).add(memberId);
    }

    return groupRows
        .map(
          (row) => MemberGroup.fromMap(
            row,
            memberIds: byGroup[row['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<MemberGroup?> getById(String id) async {
    final rows = await _db.query(
      Tables.memberGroups,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return MemberGroup.fromMap(rows.first, memberIds: await memberIdsOf(id));
  }

  Future<List<String>> memberIdsOf(String groupId) async {
    final rows = await _db.query(
      Tables.groupMembers,
      columns: ['member_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return rows.map((row) => row['member_id']! as String).toList();
  }

  /// Lưu nhóm cùng danh sách thành viên trong một giao dịch.
  ///
  /// Dùng chung cho thêm mới và cập nhật: ghi đè bảng nối bằng cách xóa hết
  /// rồi chèn lại, vì số thành viên một nhóm luôn nhỏ và cách này không để lại
  /// bản ghi mồ côi khi bớt người.
  Future<void> save(MemberGroup group) async {
    await _database.transaction((txn) async {
      await txn.insert(
        Tables.memberGroups,
        group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        Tables.groupMembers,
        where: 'group_id = ?',
        whereArgs: [group.id],
      );

      for (final memberId in group.memberIds) {
        await txn.insert(Tables.groupMembers, {
          'group_id': group.id,
          'member_id': memberId,
        });
      }
    });
  }

  /// Soft delete nhóm. Hóa đơn cũ giữ nguyên vì `bills.group_id` chỉ là tham
  /// chiếu phụ, danh sách người tham gia đã được snapshot (SPEC FR-2.5).
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      Tables.memberGroups,
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Số nhóm mà một thành viên đang thuộc về.
  Future<int> countGroupsOfMember(String memberId) async {
    final result = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt
      FROM ${Tables.groupMembers} gm
      JOIN ${Tables.memberGroups} g ON g.id = gm.group_id
      WHERE gm.member_id = ? AND g.deleted_at IS NULL
      ''',
      [memberId],
    );
    return result.first['cnt']! as int;
  }
}
