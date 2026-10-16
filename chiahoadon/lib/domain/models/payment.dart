import 'enums.dart';

/// Một lần chuyển tiền thực tế giữa hai thành viên (SPEC FR-6.6).
///
/// Khác với `bill_participants.paid_amount` (ghi nhận trả tiền trong phạm vi
/// một hóa đơn), bảng này ghi nhận giao dịch độc lập — ví dụ quyết toán gộp
/// nhiều hóa đơn bằng một lần chuyển khoản. Khi đó [billId] là `null`.
class Payment {
  const Payment({
    required this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.paidAt,
    required this.createdAt,
    this.billId,
    this.method = PaymentMethod.transfer,
    this.note,
  });

  factory Payment.fromMap(Map<String, Object?> map) => Payment(
    id: map['id']! as String,
    billId: map['bill_id'] as String?,
    fromMemberId: map['from_member_id']! as String,
    toMemberId: map['to_member_id']! as String,
    amount: map['amount']! as int,
    paidAt: map['paid_at']! as int,
    method: PaymentMethod.fromDb(map['method'] as String?),
    note: map['note'] as String?,
    createdAt: map['created_at']! as int,
  );

  final String id;

  /// Hóa đơn liên quan, `null` nếu là quyết toán gộp.
  final String? billId;

  final String fromMemberId;
  final String toMemberId;
  final int amount;
  final int paidAt;
  final PaymentMethod method;
  final String? note;
  final int createdAt;

  bool get isStandalone => billId == null;

  Map<String, Object?> toMap() => {
    'id': id,
    'bill_id': billId,
    'from_member_id': fromMemberId,
    'to_member_id': toMemberId,
    'amount': amount,
    'paid_at': paidAt,
    'method': method.dbValue,
    'note': note,
    'created_at': createdAt,
  };

  Payment copyWith({
    int? amount,
    int? paidAt,
    PaymentMethod? method,
    String? note,
  }) => Payment(
    id: id,
    billId: billId,
    fromMemberId: fromMemberId,
    toMemberId: toMemberId,
    amount: amount ?? this.amount,
    paidAt: paidAt ?? this.paidAt,
    method: method ?? this.method,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) => other is Payment && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Payment($fromMemberId -> $toMemberId: $amount)';
}
