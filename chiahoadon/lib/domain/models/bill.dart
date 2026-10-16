import 'bill_item.dart';
import 'bill_participant.dart';
import 'enums.dart';
import 'surcharge.dart';

/// Một hóa đơn cần chia (SPEC FR-3).
///
/// Các cột `subtotal`, `totalAmount`, `shareAmount`… là kết quả đã tính của
/// split engine, được lưu lại thay vì tính lại mỗi lần đọc. Lý do: thống kê
/// truy vấn trực tiếp bằng SQL (PLAN §4.4), và hóa đơn đã chốt phải giữ nguyên
/// con số kể cả khi người dùng đổi cấu hình làm tròn sau đó.
class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.billDate,
    required this.splitType,
    required this.inputMode,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.categoryId,
    this.groupId,
    this.subtotal = 0,
    this.discount = const Surcharge.none(),
    this.discountAmount = 0,
    this.tax = const Surcharge.none(),
    this.taxAmount = 0,
    this.service = const Surcharge.none(),
    this.serviceAmount = 0,
    this.tipAmount = 0,
    this.surchargeAlloc = SurchargeAlloc.proportional,
    this.roundingUnit = 1000,
    this.roundingMode = RoundingMode.up,
    this.totalExact = 0,
    this.totalAmount = 0,
    this.roundingDelta = 0,
    this.status = BillStatus.draft,
    this.imagePath,
    this.deletedAt,
    this.participants = const [],
    this.payers = const [],
    this.items = const [],
  });

  factory Bill.fromMap(
    Map<String, Object?> map, {
    List<BillParticipant> participants = const [],
    List<BillPayer> payers = const [],
    List<BillItem> items = const [],
  }) => Bill(
    id: map['id']! as String,
    title: map['title']! as String,
    note: map['note'] as String?,
    billDate: map['bill_date']! as int,
    categoryId: map['category_id'] as String?,
    groupId: map['group_id'] as String?,
    splitType: SplitType.fromDb(map['split_type'] as String?),
    inputMode: InputMode.fromDb(map['input_mode'] as String?),
    subtotal: map['subtotal']! as int,
    discount: Surcharge.fromDb(
      mode: map['discount_mode'] as String?,
      value: map['discount_value']! as int,
    ),
    discountAmount: map['discount_amount']! as int,
    tax: Surcharge.fromDb(
      mode: map['tax_mode'] as String?,
      value: map['tax_value']! as int,
    ),
    taxAmount: map['tax_amount']! as int,
    service: Surcharge.fromDb(
      mode: map['service_mode'] as String?,
      value: map['service_value']! as int,
    ),
    serviceAmount: map['service_amount']! as int,
    tipAmount: map['tip_amount']! as int,
    surchargeAlloc: SurchargeAlloc.fromDb(map['surcharge_alloc'] as String?),
    roundingUnit: map['rounding_unit']! as int,
    roundingMode: RoundingMode.fromDb(map['rounding_mode'] as String?),
    totalExact: map['total_exact']! as int,
    totalAmount: map['total_amount']! as int,
    roundingDelta: map['rounding_delta']! as int,
    status: BillStatus.fromDb(map['status'] as String?),
    imagePath: map['image_path'] as String?,
    createdAt: map['created_at']! as int,
    updatedAt: map['updated_at']! as int,
    deletedAt: map['deleted_at'] as int?,
    participants: participants,
    payers: payers,
    items: items,
  );

  final String id;
  final String title;
  final String? note;

  /// Mốc 00:00 giờ địa phương của ngày hóa đơn, dạng epoch milli.
  final int billDate;

  final String? categoryId;
  final String? groupId;

  final SplitType splitType;
  final InputMode inputMode;

  // ─── Các mốc tiền, theo đúng thứ tự tính ở SPEC §FR-5 ───

  /// Tổng thành tiền các món, hoặc tổng nhập tay. Trước giảm giá và phụ phí.
  final int subtotal;

  final Surcharge discount;
  final int discountAmount;

  final Surcharge tax;
  final int taxAmount;

  final Surcharge service;
  final int serviceAmount;

  final int tipAmount;

  final SurchargeAlloc surchargeAlloc;

  // ─── Làm tròn ───
  final int roundingUnit;
  final RoundingMode roundingMode;

  /// Tổng trước khi làm tròn.
  final int totalExact;

  /// Tổng sau làm tròn. Bất biến của hệ thống: bằng tổng `shareAmount` của
  /// mọi người tham gia (SPEC FR-4).
  final int totalAmount;

  /// `totalAmount - totalExact`. Hiện lên UI để người dùng hiểu vì sao lệch
  /// vài trăm đồng (SPEC FR-5.9).
  final int roundingDelta;

  final BillStatus status;

  /// Đường dẫn tương đối tới ảnh hóa đơn trong app documents dir.
  final String? imagePath;

  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  // ─── Quan hệ, nạp rời khi cần ───
  final List<BillParticipant> participants;
  final List<BillPayer> payers;
  final List<BillItem> items;

  /// Mức tiền sau giảm giá, là gốc để tính VAT và phí dịch vụ.
  int get base => subtotal - discountAmount;

  /// Tổng phụ phí cộng thêm.
  int get surchargeTotal => taxAmount + serviceAmount + tipAmount;

  int get participantCount => participants.length;

  /// Tổng số tiền đã ứng trước. Phải bằng [totalAmount].
  int get totalPaidByPayers =>
      payers.fold(0, (sum, p) => sum + p.paidAmount);

  /// Tổng số tiền người tham gia đã trả lại cho người ứng.
  int get totalSettled =>
      participants.fold(0, (sum, p) => sum + p.paidAmount);

  /// Tổng phần chịu của mọi người. Dùng để kiểm tra bất biến `== totalAmount`.
  int get totalShares =>
      participants.fold(0, (sum, p) => sum + p.shareAmount);

  bool get hasSurcharge =>
      discount.isActive || tax.isActive || service.isActive || tipAmount != 0;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// Người ứng tiền duy nhất, hoặc `null` nếu có nhiều người cùng ứng.
  String? get singlePayerId =>
      payers.length == 1 ? payers.first.memberId : null;

  /// Trạng thái suy ra từ số tiền đã trả của từng người (SPEC FR-6.2).
  ///
  /// Không dùng trực tiếp [status] khi tính, để UI và DB không lệch nhau khi
  /// người dùng vừa đánh dấu đã trả.
  BillStatus get derivedStatus {
    if (status == BillStatus.draft) return BillStatus.draft;
    if (participants.isEmpty) return BillStatus.unpaid;

    // Người ứng tiền tự chịu phần của mình thì coi như đã trả.
    final payerIds = payers.map((p) => p.memberId).toSet();
    final owing = participants.where((p) => !payerIds.contains(p.memberId));

    if (owing.isEmpty) return BillStatus.settled;
    if (owing.every((p) => p.paidAmount >= p.shareAmount)) {
      return BillStatus.settled;
    }
    if (owing.any((p) => p.paidAmount > 0)) return BillStatus.partial;
    return BillStatus.unpaid;
  }

  BillParticipant? participantOf(String memberId) {
    for (final p in participants) {
      if (p.memberId == memberId) return p;
    }
    return null;
  }

  /// Chỉ các cột của chính bảng `bills`; quan hệ lưu ở bảng riêng.
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'note': note,
    'bill_date': billDate,
    'category_id': categoryId,
    'group_id': groupId,
    'split_type': splitType.dbValue,
    'input_mode': inputMode.dbValue,
    'subtotal': subtotal,
    'discount_mode': discount.mode.dbValue,
    'discount_value': discount.value,
    'discount_amount': discountAmount,
    'tax_mode': tax.mode.dbValue,
    'tax_value': tax.value,
    'tax_amount': taxAmount,
    'service_mode': service.mode.dbValue,
    'service_value': service.value,
    'service_amount': serviceAmount,
    'tip_amount': tipAmount,
    'surcharge_alloc': surchargeAlloc.dbValue,
    'rounding_unit': roundingUnit,
    'rounding_mode': roundingMode.dbValue,
    'total_exact': totalExact,
    'total_amount': totalAmount,
    'rounding_delta': roundingDelta,
    'status': status.dbValue,
    'image_path': imagePath,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  Bill copyWith({
    String? title,
    String? note,
    int? billDate,
    String? categoryId,
    String? groupId,
    SplitType? splitType,
    InputMode? inputMode,
    int? subtotal,
    Surcharge? discount,
    int? discountAmount,
    Surcharge? tax,
    int? taxAmount,
    Surcharge? service,
    int? serviceAmount,
    int? tipAmount,
    SurchargeAlloc? surchargeAlloc,
    int? roundingUnit,
    RoundingMode? roundingMode,
    int? totalExact,
    int? totalAmount,
    int? roundingDelta,
    BillStatus? status,
    String? imagePath,
    int? updatedAt,
    int? deletedAt,
    List<BillParticipant>? participants,
    List<BillPayer>? payers,
    List<BillItem>? items,
    bool clearDeletedAt = false,
    bool clearCategory = false,
    bool clearGroup = false,
    bool clearImage = false,
  }) => Bill(
    id: id,
    title: title ?? this.title,
    note: note ?? this.note,
    billDate: billDate ?? this.billDate,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    splitType: splitType ?? this.splitType,
    inputMode: inputMode ?? this.inputMode,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    discountAmount: discountAmount ?? this.discountAmount,
    tax: tax ?? this.tax,
    taxAmount: taxAmount ?? this.taxAmount,
    service: service ?? this.service,
    serviceAmount: serviceAmount ?? this.serviceAmount,
    tipAmount: tipAmount ?? this.tipAmount,
    surchargeAlloc: surchargeAlloc ?? this.surchargeAlloc,
    roundingUnit: roundingUnit ?? this.roundingUnit,
    roundingMode: roundingMode ?? this.roundingMode,
    totalExact: totalExact ?? this.totalExact,
    totalAmount: totalAmount ?? this.totalAmount,
    roundingDelta: roundingDelta ?? this.roundingDelta,
    status: status ?? this.status,
    imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    participants: participants ?? this.participants,
    payers: payers ?? this.payers,
    items: items ?? this.items,
  );

  @override
  bool operator ==(Object other) =>
      other is Bill && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);

  @override
  String toString() => 'Bill($id, $title, $totalAmount)';
}
