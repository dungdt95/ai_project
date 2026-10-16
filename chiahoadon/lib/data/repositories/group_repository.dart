import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/result.dart';
import '../../domain/models/member_group.dart';
import '../dao/group_dao.dart';

/// Nghiệp vụ quản lý nhóm thành viên (SPEC FR-2).
class GroupRepository {
  const GroupRepository(this._groupDao);

  static const Uuid _uuid = Uuid();

  final GroupDao _groupDao;

  Future<Result<List<MemberGroup>>> getAll() =>
      Result.guard(_groupDao.getAll);

  Future<Result<MemberGroup?>> getById(String id) =>
      Result.guard(() => _groupDao.getById(id));

  Future<Result<MemberGroup>> create({
    required String name,
    required List<String> memberIds,
    String? description,
    int? color,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError.validation('Tên nhóm không được để trống.'));
    }
    if (memberIds.isEmpty) {
      return const Err(
        AppError.validation('Nhóm cần có ít nhất một thành viên.'),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final group = MemberGroup(
      id: _uuid.v4(),
      name: trimmed,
      description: description?.trim(),
      color: color ?? _nextColor(now),
      createdAt: now,
      updatedAt: now,
      memberIds: memberIds,
    );

    return Result.guard(() async {
      await _groupDao.save(group);
      return group;
    });
  }

  Future<Result<MemberGroup>> update(MemberGroup group) async {
    if (group.name.trim().isEmpty) {
      return const Err(AppError.validation('Tên nhóm không được để trống.'));
    }
    if (group.memberIds.isEmpty) {
      return const Err(
        AppError.validation('Nhóm cần có ít nhất một thành viên.'),
      );
    }

    final updated = group.copyWith(
      name: group.name.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return Result.guard(() async {
      await _groupDao.save(updated);
      return updated;
    });
  }

  /// Soft delete. Hóa đơn cũ của nhóm vẫn còn nguyên (SPEC FR-2.5).
  Future<Result<void>> delete(String id) =>
      Result.guard(() => _groupDao.softDelete(id));

  /// Màu nhận diện cho nhóm mới, lấy luân phiên trong bảng màu.
  static int _nextColor(int seed) => AppColors
      .avatarPalette[seed % AppColors.avatarPalette.length]
      .toARGB32();
}
