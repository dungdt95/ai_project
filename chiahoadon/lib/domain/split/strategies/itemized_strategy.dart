import '../split_input.dart';
import 'split_strategy.dart';

/// Chia theo món — "chia theo giá dịch vụ của từng người" (SPEC FR-4.2).
///
/// Giá ghi trên món là giá **một phần**. Mỗi người dùng món trả đúng giá đó,
/// nên thành tiền của món là `đơn giá × số người`:
///
/// ```
/// Phở bò     60.000/phần  →  An, Bình        →  60.000 mỗi người  = 120.000
/// Bún chả    55.000/phần  →  Chi             →  55.000            =  55.000
/// Trà đá      5.000/phần  →  An, Bình, Chi   →   5.000 mỗi người  =  15.000
/// Cà phê     25.000/phần  →  An              →  25.000            =  25.000
/// ─────────────────────────────────────────────────────────────────────────
/// An = 90.000   ·   Bình = 65.000   ·   Chi = 60.000        (Σ = 215.000)
/// ```
///
/// **Không có phép chia nào ở đây**, nên cũng không có phần dư: mỗi người trả
/// đúng một bội số nguyên của đơn giá. Việc làm tròn và phân bổ phụ phí vẫn
/// dùng Largest Remainder ở các bước sau của engine.
///
/// Ai dùng nhiều phần hơn thì nhân lên theo số phần: "Bình uống 2 lon bia, An
/// 1 lon" → Bình trả gấp đôi An.
class ItemizedStrategy implements SplitStrategy {
  const ItemizedStrategy();

  @override
  BaseShares baseShares(SplitInput input) {
    final billIds = input.participantIds;
    final totals = {for (final id in billIds) id: 0};
    final byItem = <String, Map<String, int>>{};

    for (final item in input.items) {
      final allocation = _allocateItem(item, billIds);
      byItem[item.id] = allocation;

      for (final entry in allocation.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }

    return BaseShares(byMember: totals, byItem: byItem);
  }

  /// Tính phần của từng người trong một món.
  ///
  /// Món chưa chọn ai dùng được coi là món chung: mỗi người tham gia hóa đơn
  /// một phần. Giao diện không cho lưu món như vậy nữa, nhưng dữ liệu cũ vẫn
  /// có thể có — bỏ qua thì số tiền đó biến mất khỏi hóa đơn (SPEC FR-4.2).
  Map<String, int> _allocateItem(SplitItem item, List<String> billIds) {
    if (billIds.isEmpty) return const {};

    final users = item.users
        .where((user) => billIds.contains(user.memberId))
        .toList();

    if (users.isEmpty) {
      return {for (final id in billIds) id: item.unitPrice};
    }

    final allocation = <String, int>{};
    for (final user in users) {
      // Cộng dồn: cùng một người có thể xuất hiện hai lần trong dữ liệu cũ.
      allocation[user.memberId] =
          (allocation[user.memberId] ?? 0) + item.unitPrice * user.portions;
    }

    return allocation;
  }
}
