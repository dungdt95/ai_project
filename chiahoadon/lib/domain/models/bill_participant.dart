import 'enums.dart';

/// Một người chịu chi phí trong một hóa đơn (SPEC FR-3.2).
///
/// Lưu `memberNameSnapshot` và `shareAmount` đã tính để hóa đơn cũ không thay
/// đổi khi thành viên đổi tên hay khi cấu hình làm tròn thay đổi (SPEC §5.2).
class BillParticipant {
  const BillParticipant({
    required this.id,
    required this.memberId,
    required this.memberNameSnapshot,
    this.sortOrder = 0,
    this.weightNum = 1,
    this.weightDen = 1,
    this.percentBp = 0,
    this.exactAmount = 0,
    this.baseShare = 0,
    this.shareAmount = 0,
    this.paidAmount = 0,
    this.settledAt,
  });

  factory BillParticipant.fromMap(Map<String, Object?> map) => BillParticipant(
    id: map['id']! as String,
    memberId: map['member_id']! as String,
    memberNameSnapshot: map['member_name_snapshot']! as String,
    sortOrder: map['sort_order']! as int,
    weightNum: map['weight_num']! as int,
    weightDen: map['weight_den']! as int,
    percentBp: map['percent_bp']! as int,
    exactAmount: map['exact_amount']! as int,
    baseShare: map['base_share']! as int,
    shareAmount: map['share_amount']! as int,
    paidAmount: map['paid_amount']! as int,
    settledAt: map['settled_at'] as int?,
  );

  final String id;
  final String memberId;

  /// Tên thành viên lúc chốt hóa đơn.
  final String memberNameSnapshot;

  final int sortOrder;

  // ─── Tham số theo kiểu chia; chỉ một nhóm có nghĩa tùy `Bill.splitType` ───

  /// Số phần khi chia theo SHARES, dạng phân số để biểu diễn được "0,5 phần".
  final int weightNum;
  final int weightDen;

  /// Tỷ lệ khi chia theo PERCENTAGE, basis point (33,33% = 3333).
  final int percentBp;

  /// Số tiền chỉ định khi chia theo EXACT.
  final int exactAmount;

  // ─── Kết quả tính toán (cache từ split engine) ───

  /// Phần chịu trước khi phân bổ phụ phí và giảm giá.
  final int baseShare;

  /// Số tiền cuối cùng người này phải chịu. Tổng cột này bằng `bills.total_amount`.
  final int shareAmount;

  /// Đã trả lại cho người ứng tiền bao nhiêu (SPEC FR-6.1).
  final int paidAmount;

  /// Thời điểm trả xong; `null` nghĩa là chưa trả xong.
  final int? settledAt;

  double get weight => weightDen == 0 ? 0 : weightNum / weightDen;

  /// Còn nợ bao nhiêu. Âm nghĩa là đã trả thừa (xảy ra khi sửa hóa đơn sau khi
  /// người này đã trả — SPEC FR-3.13).
  int get remaining => shareAmount - paidAmount;

  bool get isOverpaid => paidAmount > shareAmount;

  ParticipantPaymentStatus get status {
    if (paidAmount <= 0) return ParticipantPaymentStatus.unpaid;
    if (paidAmount >= shareAmount) return ParticipantPaymentStatus.paid;
    return ParticipantPaymentStatus.partial;
  }

  Map<String, Object?> toMap(String billId) => {
    'id': id,
    'bill_id': billId,
    'member_id': memberId,
    'member_name_snapshot': memberNameSnapshot,
    'sort_order': sortOrder,
    'weight_num': weightNum,
    'weight_den': weightDen,
    'percent_bp': percentBp,
    'exact_amount': exactAmount,
    'base_share': baseShare,
    'share_amount': shareAmount,
    'paid_amount': paidAmount,
    'settled_at': settledAt,
  };

  BillParticipant copyWith({
    String? memberNameSnapshot,
    int? sortOrder,
    int? weightNum,
    int? weightDen,
    int? percentBp,
    int? exactAmount,
    int? baseShare,
    int? shareAmount,
    int? paidAmount,
    int? settledAt,
    bool clearSettledAt = false,
  }) => BillParticipant(
    id: id,
    memberId: memberId,
    memberNameSnapshot: memberNameSnapshot ?? this.memberNameSnapshot,
    sortOrder: sortOrder ?? this.sortOrder,
    weightNum: weightNum ?? this.weightNum,
    weightDen: weightDen ?? this.weightDen,
    percentBp: percentBp ?? this.percentBp,
    exactAmount: exactAmount ?? this.exactAmount,
    baseShare: baseShare ?? this.baseShare,
    shareAmount: shareAmount ?? this.shareAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    settledAt: clearSettledAt ? null : (settledAt ?? this.settledAt),
  );

  @override
  String toString() =>
      'BillParticipant($memberNameSnapshot, share=$shareAmount, paid=$paidAmount)';
}

/// Một người ứng tiền trả trước cho hóa đơn (SPEC FR-3.3, FR-3.4).
///
/// Tách khỏi [BillParticipant] vì người ứng tiền không bắt buộc phải là người
/// chịu chi phí — ví dụ bố trả hộ cho nhóm con (SPEC FR-3, quy tắc nghiệp vụ).
class BillPayer {
  const BillPayer({required this.memberId, required this.paidAmount});

  factory BillPayer.fromMap(Map<String, Object?> map) => BillPayer(
    memberId: map['member_id']! as String,
    paidAmount: map['paid_amount']! as int,
  );

  final String memberId;

  /// Số tiền người này đã ứng. Tổng cột này phải bằng `bills.total_amount`.
  final int paidAmount;

  Map<String, Object?> toMap(String billId) => {
    'bill_id': billId,
    'member_id': memberId,
    'paid_amount': paidAmount,
  };

  BillPayer copyWith({int? paidAmount}) =>
      BillPayer(memberId: memberId, paidAmount: paidAmount ?? this.paidAmount);

  @override
  bool operator ==(Object other) =>
      other is BillPayer &&
      other.memberId == memberId &&
      other.paidAmount == paidAmount;

  @override
  int get hashCode => Object.hash(memberId, paidAmount);

  @override
  String toString() => 'BillPayer($memberId, $paidAmount)';
}
