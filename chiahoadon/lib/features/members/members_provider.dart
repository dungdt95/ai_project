import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../core/utils/vn_text.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/models/member.dart';

/// Toàn bộ thành viên, **kể cả người đã ngừng hoạt động**.
///
/// Màn hình quản lý cần thấy cả người ngừng hoạt động để bật lại được; nơi nào
/// chỉ cần người chọn được thì lọc qua [selectableMembersProvider].
class MembersNotifier extends AsyncNotifier<List<Member>> {
  @override
  Future<List<Member>> build() async {
    final result = await ref
        .watch(memberRepositoryProvider)
        .getAll(includeInactive: true);

    return result.when(
      ok: (members) => members,
      err: (error) => throw error,
    );
  }

  MemberRepository get _repository => ref.read(memberRepositoryProvider);

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
    final result = await _repository.create(
      name: name,
      nickname: nickname,
      phone: phone,
      bankName: bankName,
      bankBin: bankBin,
      bankAccount: bankAccount,
      bankHolder: bankHolder,
      note: note,
    );
    if (result.isOk) _reload();
    return result;
  }

  /// Nhập nhanh nhiều thành viên, mỗi dòng một tên (SPEC FR-1.8).
  Future<Result<List<Member>>> createMany(String multilineNames) async {
    final result = await _repository.createMany(multilineNames);
    if (result.isOk) _reload();
    return result;
  }

  Future<Result<Member>> save(Member member) async {
    final result = await _repository.update(member);
    if (result.isOk) _reload();
    return result;
  }

  /// Chuyển đánh dấu "Tôi" sang thành viên khác (SPEC FR-1.6).
  Future<Result<void>> setSelf(String id) async {
    final result = await _repository.setSelf(id);
    if (result.isOk) _reload();
    return result;
  }

  Future<Result<void>> setActive(String id, {required bool isActive}) async {
    final result = await _repository.setActive(id, isActive);
    if (result.isOk) _reload();
    return result;
  }

  /// Những thành viên đã có cùng tên, sau khi bỏ dấu.
  ///
  /// Danh sách rỗng nghĩa là không trùng. Trùng tên **không** bị chặn — nhóm có
  /// thể thật sự có hai bạn tên "Anh" — nên lỗi đọc dữ liệu ở đây cũng trả về
  /// rỗng, để một sự cố phụ không chặn được việc thêm người.
  Future<List<Member>> checkDuplicates(
    String name, {
    String? excludeId,
  }) async {
    final result = await _repository.findDuplicates(name, excludeId: excludeId);
    return result.valueOr(const []);
  }

  /// Kiểm tra trước khi xóa, để UI biết nên hiện hộp thoại nào (SPEC FR-1.5).
  Future<Result<MemberDeletionCheck>> checkDeletion(String id) =>
      _repository.checkDeletion(id);

  Future<Result<MemberDeletionOutcome>> delete(String id) async {
    final result = await _repository.delete(id);
    if (result.isOk) _reload();
    return result;
  }

  /// Nạp lại danh sách sau khi ghi.
  ///
  /// Hủy luôn [selfMemberProvider] vì nó đọc cùng dữ liệu và được dùng làm
  /// người trả trước mặc định ở form hóa đơn.
  void _reload() {
    ref.invalidate(selfMemberProvider);
    ref.invalidateSelf();
  }
}

final membersProvider =
    AsyncNotifierProvider<MembersNotifier, List<Member>>(MembersNotifier.new);

/// Chỉ những thành viên chọn được vào hóa đơn mới (SPEC FR-1.5).
final selectableMembersProvider = Provider<List<Member>>((ref) {
  final members = ref.watch(membersProvider).value ?? const [];
  return members.where((member) => member.isSelectable).toList();
});

/// Từ khóa tìm kiếm trong danh sách thành viên (SPEC FR-1.7).
class MemberQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final memberQueryProvider =
    NotifierProvider<MemberQueryNotifier, String>(MemberQueryNotifier.new);

/// Danh sách thành viên đã lọc theo từ khóa, bỏ qua dấu tiếng Việt.
///
/// Lọc trong bộ nhớ thay vì truy vấn lại DB: số thành viên luôn nhỏ, nên cách
/// này cho kết quả ngay theo từng ký tự gõ vào, không có nhịp chờ nào.
final filteredMembersProvider = Provider<AsyncValue<List<Member>>>((ref) {
  final query = ref.watch(memberQueryProvider);

  return ref.watch(membersProvider).whenData((members) {
    if (query.trim().isEmpty) return members;

    final normalized = VnText.normalize(query);
    return members
        .where(
          (member) =>
              member.nameNorm.contains(normalized) ||
              VnText.contains(member.nickname ?? '', query),
        )
        .toList();
  });
});
