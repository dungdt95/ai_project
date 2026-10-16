import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/group_repository.dart';
import '../../domain/models/member_group.dart';

/// Danh sách nhóm, kèm đủ thành viên của từng nhóm (SPEC FR-2).
class GroupsNotifier extends AsyncNotifier<List<MemberGroup>> {
  @override
  Future<List<MemberGroup>> build() async {
    final result = await ref.watch(groupRepositoryProvider).getAll();

    return result.when(
      ok: (groups) => groups,
      err: (error) => throw error,
    );
  }

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  Future<Result<MemberGroup>> create({
    required String name,
    required List<String> memberIds,
    String? description,
  }) async {
    final result = await _repository.create(
      name: name,
      memberIds: memberIds,
      description: description,
    );
    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<Result<MemberGroup>> save(MemberGroup group) async {
    final result = await _repository.update(group);
    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result = await _repository.delete(id);
    if (result.isOk) ref.invalidateSelf();
    return result;
  }
}

final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<MemberGroup>>(
      GroupsNotifier.new,
    );
