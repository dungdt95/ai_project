import 'package:uuid/uuid.dart';

import '../../core/utils/avatar_color.dart';
import '../../core/utils/result.dart';
import '../../core/utils/vn_text.dart';
import '../../domain/models/member.dart';
import '../dao/group_dao.dart';
import '../dao/member_dao.dart';

/// Nghiệp vụ quản lý thành viên (SPEC FR-1).
///
/// Repository là nơi đặt quy tắc nghiệp vụ; DAO chỉ biết đọc ghi SQL. Nhờ vậy
/// quy tắc "không xóa cứng thành viên đã có hóa đơn" chỉ tồn tại ở một chỗ.
class MemberRepository {
  const MemberRepository(this._memberDao, this._groupDao);

  static const Uuid _uuid = Uuid();

  final MemberDao _memberDao;
  final GroupDao _groupDao;

  Future<Result<List<Member>>> getAll({bool includeInactive = false}) =>
      Result.guard(() => _memberDao.getAll(includeInactive: includeInactive));

  Future<Result<Member?>> getById(String id) =>
      Result.guard(() => _memberDao.getById(id));

  Future<Result<List<Member>>> getByIds(List<String> ids) =>
      Result.guard(() => _memberDao.getByIds(ids));

  Future<Result<Member?>> getSelf() => Result.guard(_memberDao.getSelf);

  Future<Result<List<Member>>> search(String query) =>
      Result.guard(() => _memberDao.search(VnText.normalize(query)));

  /// Những thành viên trùng tên sau khi bỏ dấu.
  ///
  /// UI gọi trước khi lưu để cảnh báo; danh sách rỗng nghĩa là không trùng.
  /// Trùng tên **không** bị chặn, vì nhóm có thể thật sự có hai bạn tên "Anh"
  /// (SPEC FR-1, quy tắc nghiệp vụ).
  Future<Result<List<Member>>> findDuplicates(
    String name, {
    String? excludeId,
  }) => Result.guard(
    () => _memberDao.findByNameNorm(
      VnText.normalize(name),
      excludeId: excludeId,
    ),
  );

  /// Tạo thành viên mới. Tự sinh id, `name_norm` và màu avatar.
  Future<Result<Member>> create({
    required String name,
    String? nickname,
    String? phone,
    String? bankName,
    String? bankBin,
    String? bankAccount,
    String? bankHolder,
    String? note,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError.validation('Tên thành viên không được để trống.'));
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final member = Member(
      id: _uuid.v4(),
      name: trimmed,
      nameNorm: VnText.normalize(trimmed),
      nickname: nickname?.trim(),
      phone: phone?.trim(),
      bankName: bankName?.trim(),
      bankBin: bankBin?.trim(),
      bankAccount: bankAccount?.trim(),
      bankHolder: bankHolder?.trim(),
      avatarColor: AvatarColor.toStored(trimmed),
      note: note?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    return Result.guard(() async {
      await _memberDao.insert(member);
      return member;
    });
  }

  /// Thêm nhiều thành viên từ danh sách tên, mỗi dòng một tên (SPEC FR-1.8).
  ///
  /// Dòng trống bị bỏ qua. Tên trùng nhau trong cùng lần nhập cũng bị bỏ, vì
  /// đó gần như luôn là lỗi gõ hai lần.
  Future<Result<List<Member>>> createMany(String multilineNames) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final seen = <String>{};
    final members = <Member>[];

    for (final line in multilineNames.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final norm = VnText.normalize(trimmed);
      if (!seen.add(norm)) continue;

      members.add(
        Member(
          id: _uuid.v4(),
          name: trimmed,
          nameNorm: norm,
          avatarColor: AvatarColor.toStored(trimmed),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (members.isEmpty) {
      return const Err(AppError.validation('Chưa có tên nào hợp lệ.'));
    }

    return Result.guard(() async {
      await _memberDao.insertAll(members);
      return members;
    });
  }

  Future<Result<Member>> update(Member member) async {
    final trimmed = member.name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError.validation('Tên thành viên không được để trống.'));
    }

    final updated = member.copyWith(
      name: trimmed,
      nameNorm: VnText.normalize(trimmed),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return Result.guard(() async {
      await _memberDao.update(updated);
      return updated;
    });
  }

  /// Chuyển đánh dấu "Tôi" sang thành viên khác (SPEC FR-1.6).
  Future<Result<void>> setSelf(String id) =>
      Result.guard(() => _memberDao.setSelf(id));

  Future<Result<void>> setActive(String id, bool isActive) =>
      Result.guard(() => _memberDao.setActive(id, isActive));

  /// Kết quả kiểm tra trước khi xóa, để UI biết nên hiện hộp thoại nào.
  Future<Result<MemberDeletionCheck>> checkDeletion(String id) =>
      Result.guard(() async {
        final member = await _memberDao.getById(id);
        if (member == null) {
          throw const AppError.notFound('Không tìm thấy thành viên.');
        }
        if (member.isSelf) {
          throw const AppError.conflict(
            'Không thể xóa bản ghi "Tôi". Hãy chuyển đánh dấu này sang '
            'thành viên khác trước.',
          );
        }

        final billCount = await _memberDao.countBills(id);
        final groupCount = await _groupDao.countGroupsOfMember(id);
        final hasReference = await _memberDao.hasAnyReference(id);

        return MemberDeletionCheck(
          canHardDelete: !hasReference,
          billCount: billCount,
          groupCount: groupCount,
        );
      });

  /// Xóa thành viên.
  ///
  /// Nếu thành viên đã xuất hiện ở bất cứ đâu, chỉ chuyển sang *ngừng hoạt
  /// động* thay vì xóa — hóa đơn cũ phải giữ nguyên con số (SPEC FR-1.5).
  /// Giá trị trả về cho biết đã xóa thật hay chỉ ẩn đi.
  Future<Result<MemberDeletionOutcome>> delete(String id) async {
    final check = await checkDeletion(id);
    if (check case Err<MemberDeletionCheck>(:final error)) {
      return Err(error);
    }

    final canHardDelete = check.valueOrNull!.canHardDelete;

    return Result.guard(() async {
      if (canHardDelete) {
        await _memberDao.softDelete(id);
        return MemberDeletionOutcome.deleted;
      }
      await _memberDao.setActive(id, false);
      return MemberDeletionOutcome.deactivated;
    });
  }
}

/// Thành viên này xóa được hay chỉ ẩn được.
class MemberDeletionCheck {
  const MemberDeletionCheck({
    required this.canHardDelete,
    required this.billCount,
    required this.groupCount,
  });

  final bool canHardDelete;
  final int billCount;
  final int groupCount;

  /// Câu giải thích hiện trong hộp thoại xác nhận.
  String get reason {
    if (canHardDelete) return 'Thành viên này chưa có trong hóa đơn nào.';

    final parts = <String>[];
    if (billCount > 0) parts.add('$billCount hóa đơn');
    if (groupCount > 0) parts.add('$groupCount nhóm');
    return 'Thành viên này đang có trong ${parts.join(' và ')}. '
        'Sẽ chuyển sang trạng thái ngừng hoạt động để giữ nguyên lịch sử.';
  }
}

enum MemberDeletionOutcome {
  /// Đã xóa khỏi danh sách.
  deleted,

  /// Chỉ chuyển sang ngừng hoạt động vì còn dữ liệu liên quan.
  deactivated,
}
