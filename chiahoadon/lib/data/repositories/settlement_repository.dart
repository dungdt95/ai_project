import 'package:uuid/uuid.dart';

import '../../core/utils/result.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/payment.dart';
import '../../domain/stats/stats_models.dart';
import '../dao/payment_dao.dart';
import '../dao/stats_dao.dart';

/// Nghiệp vụ quyết toán: số dư ròng và các lần chuyển tiền (SPEC FR-6).
///
/// Thuật toán tối thiểu hóa số giao dịch nằm ở `domain/settlement/`, sẽ nối
/// vào Phase 7. Repository này lo phần dữ liệu cho nó.
class SettlementRepository {
  const SettlementRepository(this._statsDao, this._paymentDao);

  static const Uuid _uuid = Uuid();

  final StatsDao _statsDao;
  final PaymentDao _paymentDao;

  /// Số dư ròng của mọi thành viên (SPEC FR-6.4).
  Future<Result<List<MemberBalance>>> balances() =>
      Result.guard(_statsDao.balances);

  /// Chỉ những người còn số dư khác 0 — đầu vào của thuật toán quyết toán.
  Future<Result<List<MemberBalance>>> openBalances() =>
      Result.guard(() async {
        final all = await _statsDao.balances();
        return all.where((balance) => !balance.isClear).toList();
      });

  Future<Result<List<Payment>>> recentPayments({int limit = 50}) =>
      Result.guard(() => _paymentDao.getAll(limit: limit));

  Future<Result<List<Payment>>> paymentsOfMember(String memberId) =>
      Result.guard(() => _paymentDao.getByMember(memberId));

  /// Ghi nhận một lần chuyển tiền (SPEC FR-6.6).
  ///
  /// [billId] để `null` khi đây là quyết toán gộp nhiều hóa đơn.
  Future<Result<Payment>> recordPayment({
    required String fromMemberId,
    required String toMemberId,
    required int amount,
    String? billId,
    DateTime? paidAt,
    PaymentMethod method = PaymentMethod.transfer,
    String? note,
  }) async {
    if (amount <= 0) {
      return const Err(AppError.validation('Số tiền phải lớn hơn 0.'));
    }
    if (fromMemberId == toMemberId) {
      return const Err(
        AppError.validation('Người chuyển và người nhận không thể là một.'),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final payment = Payment(
      id: _uuid.v4(),
      billId: billId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      paidAt: (paidAt ?? DateTime.now()).millisecondsSinceEpoch,
      method: method,
      note: note?.trim(),
      createdAt: now,
    );

    return Result.guard(() async {
      await _paymentDao.insert(payment);
      return payment;
    });
  }

  Future<Result<void>> deletePayment(String id) =>
      Result.guard(() => _paymentDao.delete(id));

  /// Kiểm tra bất biến: tổng số dư ròng của mọi thành viên phải bằng 0.
  ///
  /// Dùng trong test và trong màn hình quyết toán — nếu khác 0 thì có hóa đơn
  /// đã bị ghi sai và cần báo cho người dùng biết (SPEC FR-6.4).
  Future<Result<int>> balanceSum() => Result.guard(() async {
    final all = await _statsDao.balances();
    return all.fold<int>(0, (sum, balance) => sum + balance.balance);
  });
}
