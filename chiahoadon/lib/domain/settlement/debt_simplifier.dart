import '../stats/stats_models.dart';

/// Một lần chuyển tiền được gợi ý để cân bằng số dư.
class SettlementTransfer {
  const SettlementTransfer({
    required this.fromMemberId,
    required this.fromName,
    required this.toMemberId,
    required this.toName,
    required this.amount,
  });

  final String fromMemberId;
  final String fromName;
  final String toMemberId;
  final String toName;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is SettlementTransfer &&
      other.fromMemberId == fromMemberId &&
      other.toMemberId == toMemberId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(fromMemberId, toMemberId, amount);

  @override
  String toString() => '$fromName -> $toName: $amount';
}

/// Rút gọn mạng lưới nợ thành số lần chuyển tiền ít nhất có thể (SPEC FR-6.5).
///
/// Thuật toán tham lam: luôn ghép người nợ nhiều nhất với người cho nợ nhiều
/// nhất. Mỗi vòng lặp đưa **ít nhất một** người về số dư 0, nên với `n` người
/// có số dư khác 0 thì kết quả tối đa `n − 1` giao dịch — thay vì để ai nợ ai
/// thì người đó tự chuyển, có thể lên tới `n × (n−1) / 2` lần.
///
/// ```
/// An +500k · Bình −300k · Chi −200k
///   → Bình chuyển An 300.000
///   → Chi  chuyển An 200.000        (2 giao dịch thay vì 4)
/// ```
///
/// Hàm thuần, không I/O, nên test được trực tiếp.
class DebtSimplifier {
  const DebtSimplifier._();

  static List<SettlementTransfer> simplify(List<MemberBalance> balances) {
    // Sắp xếp để kết quả tái lập được: cùng dữ liệu luôn cho cùng danh sách.
    final creditors =
        balances.where((balance) => balance.balance > 0).toList()
          ..sort((a, b) {
            final byAmount = b.balance.compareTo(a.balance);
            return byAmount != 0
                ? byAmount
                : a.memberId.compareTo(b.memberId);
          });

    final debtors =
        balances.where((balance) => balance.balance < 0).toList()
          ..sort((a, b) {
            final byAmount = a.balance.compareTo(b.balance);
            return byAmount != 0
                ? byAmount
                : a.memberId.compareTo(b.memberId);
          });

    if (creditors.isEmpty || debtors.isEmpty) return const [];

    // Bản sao số dư để trừ dần, không đụng vào dữ liệu gọi vào.
    final owed = {for (final c in creditors) c.memberId: c.balance};
    final owing = {for (final d in debtors) d.memberId: -d.balance};

    final transfers = <SettlementTransfer>[];
    var creditorIndex = 0;
    var debtorIndex = 0;

    while (creditorIndex < creditors.length && debtorIndex < debtors.length) {
      final creditor = creditors[creditorIndex];
      final debtor = debtors[debtorIndex];

      final remaining = owed[creditor.memberId]!;
      final due = owing[debtor.memberId]!;
      final amount = remaining < due ? remaining : due;

      if (amount > 0) {
        transfers.add(
          SettlementTransfer(
            fromMemberId: debtor.memberId,
            fromName: debtor.memberName,
            toMemberId: creditor.memberId,
            toName: creditor.memberName,
            amount: amount,
          ),
        );
      }

      owed[creditor.memberId] = remaining - amount;
      owing[debtor.memberId] = due - amount;

      if (owed[creditor.memberId] == 0) creditorIndex++;
      if (owing[debtor.memberId] == 0) debtorIndex++;
    }

    return transfers;
  }

  /// Tổng số dư của mọi thành viên. Bất biến của hệ thống: luôn bằng 0.
  ///
  /// Khác 0 nghĩa là có hóa đơn ghi sai — màn hình quyết toán cần báo cho
  /// người dùng biết thay vì im lặng đưa ra gợi ý sai (SPEC FR-6.4).
  static int balanceSum(List<MemberBalance> balances) =>
      balances.fold(0, (sum, balance) => sum + balance.balance);
}
