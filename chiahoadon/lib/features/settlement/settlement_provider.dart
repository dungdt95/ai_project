import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/payment.dart';
import '../../domain/settlement/debt_simplifier.dart';
import '../../domain/stats/stats_models.dart';
import '../bills/bills_provider.dart';

/// Toàn cảnh quyết toán của nhóm (SPEC FR-6.4, FR-6.5).
class SettlementView {
  const SettlementView({
    required this.balances,
    required this.transfers,
    required this.payments,
  });

  static const SettlementView empty = SettlementView(
    balances: [],
    transfers: [],
    payments: [],
  );

  /// Số dư ròng của mọi thành viên, đã bỏ những người đang cân bằng.
  final List<MemberBalance> balances;

  /// Các lần chuyển tiền được gợi ý để đưa mọi số dư về 0.
  final List<SettlementTransfer> transfers;

  /// Lịch sử chuyển tiền đã ghi nhận.
  final List<Payment> payments;

  bool get isSettled => balances.isEmpty;

  /// Tổng số dư. Bất biến: phải bằng 0. Khác 0 nghĩa là dữ liệu đã sai ở đâu đó.
  int get balanceSum => DebtSimplifier.balanceSum(balances);

  bool get isConsistent => balanceSum == 0;
}

class SettlementNotifier extends AsyncNotifier<SettlementView> {
  @override
  Future<SettlementView> build() async {
    // Mọi thay đổi hóa đơn đều có thể làm đổi số dư, nên theo dõi danh sách
    // hóa đơn để tự nạp lại.
    ref.watch(billListProvider);

    final repository = ref.watch(settlementRepositoryProvider);

    final balances = await repository.openBalances();
    final payments = await repository.recentPayments();

    final open = balances.when(
      ok: (list) => list,
      err: (error) => throw error,
    );

    return SettlementView(
      balances: open,
      transfers: DebtSimplifier.simplify(open),
      payments: payments.valueOr(const []),
    );
  }

  /// Ghi nhận một lần chuyển tiền (SPEC FR-6.6).
  Future<Result<Payment>> recordPayment({
    required String fromMemberId,
    required String toMemberId,
    required int amount,
    String? note,
    PaymentMethod method = PaymentMethod.transfer,
  }) async {
    final result = await ref
        .read(settlementRepositoryProvider)
        .recordPayment(
          fromMemberId: fromMemberId,
          toMemberId: toMemberId,
          amount: amount,
          note: note,
          method: method,
        );
    if (result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> deletePayment(String id) async {
    final result = await ref
        .read(settlementRepositoryProvider)
        .deletePayment(id);
    if (result.isOk) ref.invalidateSelf();
    return result;
  }
}

final settlementProvider =
    AsyncNotifierProvider<SettlementNotifier, SettlementView>(
      SettlementNotifier.new,
    );
