import 'package:uuid/uuid.dart';

import '../../../domain/models/bill.dart';
import '../../../domain/models/bill_item.dart';
import '../../../domain/models/bill_participant.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/member.dart';
import '../../../domain/models/surcharge.dart';
import '../../../domain/split/split_input.dart';
import '../../../domain/split/split_result.dart';

/// Trạng thái của form nhập hóa đơn.
///
/// Bất biến và **không phụ thuộc Flutter**: mọi thao tác của người dùng là một
/// phương thức trả về trạng thái mới. Nhờ vậy toàn bộ quy tắc của form —
/// chuyển kiểu chia, thêm bớt người, dựng đầu vào cho split engine — test được
/// trực tiếp, không cần dựng widget.
class BillFormState {
  const BillFormState({
    required this.id,
    required this.date,
    this.isEditing = false,
    this.status = BillStatus.unpaid,
    this.createdAt,
    this.title = '',
    this.note = '',
    this.categoryId,
    this.groupId,
    this.imagePath,
    this.participantIds = const [],
    this.payerId,
    this.splitType = SplitType.equal,
    this.inputMode = InputMode.total,
    this.manualTotal = 0,
    this.items = const [],
    this.percentBp = const {},
    this.weights = const {},
    this.exactAmounts = const {},
    this.discount = const Surcharge.none(),
    this.tax = const Surcharge.none(),
    this.service = const Surcharge.none(),
    this.tip = 0,
    this.surchargeAlloc = SurchargeAlloc.proportional,
    this.roundingUnit = 1000,
    this.roundingMode = RoundingMode.up,
  });

  /// Hóa đơn mới, đã chọn sẵn người trả trước là "Tôi" (SPEC FR-3.3).
  factory BillFormState.create({
    required DateTime date,
    Member? self,
    int roundingUnit = 1000,
    RoundingMode roundingMode = RoundingMode.up,
    List<String> participantIds = const [],
    String? groupId,
  }) {
    final selfId = self?.id;
    return BillFormState(
      id: const Uuid().v4(),
      date: DateTime(date.year, date.month, date.day),
      payerId: selfId,
      // Người trả trước mặc định cũng là người tham gia, vì phần lớn hóa đơn
      // là "mình trả rồi mọi người trả lại mình".
      participantIds: participantIds.isNotEmpty
          ? participantIds
          : [?selfId],
      groupId: groupId,
      // Hóa đơn mới mở thẳng ở chia theo món: chọn món có sẵn rồi chọn người
      // là đường chính. `inputMode` phải đi cùng `splitType` (xem
      // `withSplitType`), nếu không validator báo `itemizedNeedsItems` sai chỗ.
      splitType: SplitType.itemized,
      inputMode: InputMode.items,
      roundingUnit: roundingUnit,
      roundingMode: roundingMode,
    );
  }

  /// Nạp một hóa đơn đã lưu để sửa (SPEC FR-3.13).
  factory BillFormState.edit(Bill bill) => BillFormState(
    id: bill.id,
    isEditing: true,
    status: bill.status,
    createdAt: bill.createdAt,
    title: bill.title,
    note: bill.note ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(bill.billDate),
    categoryId: bill.categoryId,
    groupId: bill.groupId,
    imagePath: bill.imagePath,
    participantIds: [for (final p in bill.participants) p.memberId],
    payerId: bill.payers.isEmpty ? null : bill.payers.first.memberId,
    splitType: bill.splitType,
    inputMode: bill.inputMode,
    manualTotal: bill.inputMode == InputMode.total ? bill.subtotal : 0,
    items: bill.items,
    percentBp: {for (final p in bill.participants) p.memberId: p.percentBp},
    weights: {
      for (final p in bill.participants)
        p.memberId: (num: p.weightNum, den: p.weightDen),
    },
    exactAmounts: {
      for (final p in bill.participants) p.memberId: p.exactAmount,
    },
    discount: bill.discount,
    tax: bill.tax,
    service: bill.service,
    tip: bill.tipAmount,
    surchargeAlloc: bill.surchargeAlloc,
    roundingUnit: bill.roundingUnit,
    roundingMode: bill.roundingMode,
  );

  final String id;
  final bool isEditing;
  final BillStatus status;
  final int? createdAt;

  // ─── Bước 1: thông tin ───
  final String title;
  final String note;
  final DateTime date;
  final String? categoryId;
  final String? groupId;
  final String? imagePath;

  // ─── Bước 2: người tham gia ───

  /// Thứ tự trong danh sách quyết định ai nhận phần dư khi chia không hết,
  /// nên phải giữ ổn định (SPEC §FR-5).
  final List<String> participantIds;

  final String? payerId;

  // ─── Bước 3: cách chia ───
  final SplitType splitType;
  final InputMode inputMode;
  final int manualTotal;
  final List<BillItem> items;

  /// Tham số riêng của từng kiểu chia, giữ lại khi người dùng đổi qua lại.
  final Map<String, int> percentBp;
  final Map<String, ({int num, int den})> weights;
  final Map<String, int> exactAmounts;

  final Surcharge discount;
  final Surcharge tax;
  final Surcharge service;
  final int tip;
  final SurchargeAlloc surchargeAlloc;
  final int roundingUnit;
  final RoundingMode roundingMode;

  int get participantCount => participantIds.length;

  bool get hasParticipants => participantIds.isNotEmpty;

  bool get hasSurcharge =>
      discount.isActive || tax.isActive || service.isActive || tip != 0;

  /// Tổng tiền trước giảm giá và phụ phí.
  /// Tạm tính: tổng thành tiền các món, hoặc số tổng nhập tay.
  ///
  /// Món tính theo giá × số phần, nên thêm một người vào món là tạm tính tăng
  /// lên ngay (SPEC FR-4.2).
  int get subtotal => inputMode == InputMode.items
      ? items.fold(
          0,
          (sum, item) => sum + item.amountFor(participantIds.length),
        )
      : manualTotal;

  /// Form đã đủ điều kiện lưu chính thức hay chưa.
  ///
  /// Chỉ kiểm tra những gì người dùng nhìn thấy; bất biến về tổng tiền do
  /// `BillRepository.validate` lo sau khi split engine chạy xong.
  bool get canSave =>
      title.trim().isNotEmpty && hasParticipants && subtotal > 0;

  /// Lý do chưa lưu được, để hiện ngay dưới nút lưu.
  String? get blockingReason {
    if (title.trim().isEmpty) return 'Hóa đơn cần có tên';
    if (!hasParticipants) return 'Chọn ít nhất một người tham gia';
    if (subtotal <= 0) {
      return inputMode == InputMode.items
          ? 'Thêm ít nhất một món có số tiền'
          : 'Nhập tổng tiền lớn hơn 0';
    }
    return null;
  }

  // ─────────────────────── thao tác của người dùng ───────────────────────

  BillFormState withTitle(String value) => copyWith(title: value);

  BillFormState withNote(String value) => copyWith(note: value);

  BillFormState withDate(DateTime value) =>
      copyWith(date: DateTime(value.year, value.month, value.day));

  BillFormState withCategory(String? value) =>
      copyWith(categoryId: value, clearCategory: value == null);

  BillFormState withTotal(int value) => copyWith(manualTotal: value);

  /// Đổi danh sách người tham gia.
  ///
  /// Giữ nguyên thứ tự cũ của những người vẫn còn, rồi mới nối người mới vào
  /// cuối — để việc bỏ một người ra không làm xáo trộn ai đang nhận phần dư.
  BillFormState withParticipants(Set<String> ids) {
    final kept = [for (final id in participantIds) if (ids.contains(id)) id];
    final added = [for (final id in ids) if (!participantIds.contains(id)) id];
    final next = [...kept, ...added];

    return copyWith(
      participantIds: next,
      // Người trả trước bị bỏ khỏi hóa đơn thì vẫn giữ nguyên: người ứng tiền
      // không bắt buộc phải là người tham gia (SPEC FR-3, quy tắc nghiệp vụ).
      payerId: payerId,
    ).pruneItemUsers();
  }

  BillFormState toggleParticipant(String memberId) {
    final next = {...participantIds};
    if (!next.remove(memberId)) next.add(memberId);
    return withParticipants(next);
  }

  BillFormState withPayer(String? memberId) =>
      copyWith(payerId: memberId, clearPayer: memberId == null);

  /// Chọn cả nhóm: thay danh sách người tham gia và ghi nhớ nhóm đã chọn.
  BillFormState withGroup(String? groupId, {Set<String>? memberIds}) =>
      memberIds == null
      ? copyWith(groupId: groupId, clearGroup: groupId == null)
      : withParticipants(memberIds).copyWith(groupId: groupId);

  /// Đổi kiểu chia.
  ///
  /// Chuyển sang chia theo món thì tự chuyển chế độ nhập sang danh sách món,
  /// vì hai thứ đó luôn đi cùng nhau (SPEC FR-4.2, lỗi `itemizedNeedsItems`).
  BillFormState withSplitType(SplitType value) => copyWith(
    splitType: value,
    inputMode: value == SplitType.itemized
        ? InputMode.items
        : InputMode.total,
  );

  // ─── Danh sách món (SPEC FR-3.7) ───

  BillFormState addItem(BillItem item) => copyWith(
    items: [...items, item.copyWith(sortOrder: items.length)],
  );

  BillFormState updateItem(BillItem item) => copyWith(
    items: [
      for (final existing in items)
        if (existing.id == item.id) item else existing,
    ],
  );

  BillFormState removeItem(String itemId) => copyWith(
    items: [
      for (final (index, item) in items
          .where((item) => item.id != itemId)
          .indexed)
        item.copyWith(sortOrder: index),
    ],
  );

  /// Bỏ khỏi mọi món những người không còn tham gia hóa đơn.
  ///
  /// Nếu để sót, split engine sẽ báo lỗi `itemUserNotParticipant` và người dùng
  /// không hiểu vì sao — họ đâu có thấy người đó ở đâu nữa.
  BillFormState pruneItemUsers() {
    final allowed = participantIds.toSet();

    return copyWith(
      items: [
        for (final item in items)
          item.copyWith(
            participants: [
              for (final user in item.participants)
                if (allowed.contains(user.memberId)) user,
            ],
          ),
      ],
    );
  }

  // ─── Tham số của từng kiểu chia (SPEC FR-4.3 → FR-4.5) ───

  /// Đặt tỷ lệ phần trăm của một người, đơn vị basis point (8% → 800).
  BillFormState withPercent(String memberId, int basisPoints) =>
      copyWith(percentBp: {...percentBp, memberId: basisPoints});

  /// Chia đều 100% cho mọi người, phần dư dồn cho người đầu để tổng đúng 10.000bp.
  BillFormState withEvenPercents() {
    if (participantIds.isEmpty) return this;

    final each = 10000 ~/ participantCount;
    final remainder = 10000 - each * participantCount;

    return copyWith(
      percentBp: {
        for (var i = 0; i < participantCount; i++)
          participantIds[i]: each + (i == 0 ? remainder : 0),
      },
    );
  }

  /// Tổng phần trăm hiện tại, đơn vị basis point. Phải bằng 10.000 mới lưu được.
  int get totalPercentBp => participantIds.fold(
    0,
    (sum, id) => sum + (percentBp[id] ?? 0),
  );

  BillFormState withWeight(String memberId, int parts) => copyWith(
    weights: {...weights, memberId: (num: parts < 0 ? 0 : parts, den: 1)},
  );

  int weightOf(String memberId) => weights[memberId]?.num ?? 1;

  int get totalWeight =>
      participantIds.fold(0, (sum, id) => sum + weightOf(id));

  BillFormState withExactAmount(String memberId, int amount) =>
      copyWith(exactAmounts: {...exactAmounts, memberId: amount});

  int get totalExactAmount =>
      participantIds.fold(0, (sum, id) => sum + (exactAmounts[id] ?? 0));

  /// Số tiền còn lại chưa được phân bổ khi chia theo số tiền chỉ định.
  /// Âm nghĩa là đã phân bổ vượt (SPEC FR-4.5).
  int get unallocatedAmount => subtotal - totalExactAmount;

  BillFormState withDiscount(Surcharge value) => copyWith(discount: value);

  BillFormState withTax(Surcharge value) => copyWith(tax: value);

  BillFormState withService(Surcharge value) => copyWith(service: value);

  BillFormState withTip(int value) => copyWith(tip: value);

  BillFormState withRounding({int? unit, RoundingMode? mode}) =>
      copyWith(roundingUnit: unit, roundingMode: mode);

  BillFormState withSurchargeAlloc(SurchargeAlloc value) =>
      copyWith(surchargeAlloc: value);

  // ─────────────────────── nối với split engine ───────────────────────

  /// Đầu vào cho `computeSplit`.
  SplitInput toSplitInput() => SplitInput(
    participants: [
      for (final memberId in participantIds)
        SplitParticipant(
          memberId: memberId,
          weightNum: weights[memberId]?.num ?? 1,
          weightDen: weights[memberId]?.den ?? 1,
          percentBp: percentBp[memberId] ?? 0,
          exactAmount: exactAmounts[memberId] ?? 0,
        ),
    ],
    splitType: splitType,
    inputMode: inputMode,
    manualTotal: manualTotal,
    items: [
      for (final item in items)
        SplitItem(
          id: item.id,
          unitPrice: item.unitPrice,
          users: [
            for (final user in item.participants)
              SplitItemShare(
                memberId: user.memberId,
                weightNum: user.weightNum,
                weightDen: user.weightDen,
              ),
          ],
        ),
    ],
    discount: discount,
    tax: tax,
    service: service,
    tip: tip,
    surchargeAlloc: surchargeAlloc,
    roundingUnit: roundingUnit,
    roundingMode: roundingMode,
  );

  /// Dựng bản ghi để lưu xuống DB, lấy số tiền từ kết quả của split engine.
  ///
  /// [memberNames] dùng để chụp lại tên từng người tại thời điểm chốt hóa đơn,
  /// nhờ đó đổi tên thành viên về sau không làm thay đổi hóa đơn cũ (SPEC §5.2).
  Bill toBill(SplitResult result, Map<String, String> memberNames) {
    final now = DateTime.now().millisecondsSinceEpoch;

    return Bill(
      id: id,
      title: title.trim(),
      note: note.trim().isEmpty ? null : note.trim(),
      billDate: date.millisecondsSinceEpoch,
      categoryId: categoryId,
      groupId: groupId,
      splitType: splitType,
      inputMode: inputMode,
      subtotal: result.subtotal,
      discount: discount,
      discountAmount: result.discountAmount,
      tax: tax,
      taxAmount: result.taxAmount,
      service: service,
      serviceAmount: result.serviceAmount,
      tipAmount: result.tipAmount,
      surchargeAlloc: surchargeAlloc,
      roundingUnit: roundingUnit,
      roundingMode: roundingMode,
      totalExact: result.totalExact,
      totalAmount: result.total,
      roundingDelta: result.roundingDelta,
      status: status == BillStatus.draft ? BillStatus.unpaid : status,
      imagePath: imagePath,
      createdAt: createdAt ?? now,
      updatedAt: now,
      payers: [
        if (payerId != null)
          BillPayer(memberId: payerId!, paidAmount: result.total),
      ],
      participants: [
        for (var i = 0; i < participantIds.length; i++)
          BillParticipant(
            id: const Uuid().v4(),
            memberId: participantIds[i],
            memberNameSnapshot: memberNames[participantIds[i]] ?? '?',
            sortOrder: i,
            weightNum: weights[participantIds[i]]?.num ?? 1,
            weightDen: weights[participantIds[i]]?.den ?? 1,
            percentBp: percentBp[participantIds[i]] ?? 0,
            exactAmount: exactAmounts[participantIds[i]] ?? 0,
            baseShare: result.baseShareOf(participantIds[i]),
            shareAmount: result.shareOf(participantIds[i]),
          ),
      ],
      items: items,
    );
  }

  /// Bản nháp để tự lưu trong lúc người dùng còn đang nhập (SPEC FR-3.10).
  ///
  /// Không chạy split engine: nháp có thể chưa đủ dữ liệu để chia, và bất biến
  /// về tổng tiền chỉ được kiểm tra khi lưu chính thức.
  Bill toDraft(Map<String, String> memberNames) {
    final now = DateTime.now().millisecondsSinceEpoch;

    return Bill(
      id: id,
      title: title.trim().isEmpty ? 'Hóa đơn chưa đặt tên' : title.trim(),
      note: note.trim().isEmpty ? null : note.trim(),
      billDate: date.millisecondsSinceEpoch,
      categoryId: categoryId,
      groupId: groupId,
      splitType: splitType,
      inputMode: inputMode,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      service: service,
      tipAmount: tip,
      surchargeAlloc: surchargeAlloc,
      roundingUnit: roundingUnit,
      roundingMode: roundingMode,
      status: BillStatus.draft,
      imagePath: imagePath,
      createdAt: createdAt ?? now,
      updatedAt: now,
      payers: [
        if (payerId != null) BillPayer(memberId: payerId!, paidAmount: 0),
      ],
      participants: [
        for (var i = 0; i < participantIds.length; i++)
          BillParticipant(
            id: const Uuid().v4(),
            memberId: participantIds[i],
            memberNameSnapshot: memberNames[participantIds[i]] ?? '?',
            sortOrder: i,
          ),
      ],
      items: items,
    );
  }

  BillFormState copyWith({
    String? title,
    String? note,
    DateTime? date,
    String? categoryId,
    String? groupId,
    String? imagePath,
    List<String>? participantIds,
    String? payerId,
    SplitType? splitType,
    InputMode? inputMode,
    int? manualTotal,
    List<BillItem>? items,
    Map<String, int>? percentBp,
    Map<String, ({int num, int den})>? weights,
    Map<String, int>? exactAmounts,
    Surcharge? discount,
    Surcharge? tax,
    Surcharge? service,
    int? tip,
    SurchargeAlloc? surchargeAlloc,
    int? roundingUnit,
    RoundingMode? roundingMode,
    BillStatus? status,
    bool clearCategory = false,
    bool clearGroup = false,
    bool clearPayer = false,
    bool clearImage = false,
  }) => BillFormState(
    id: id,
    isEditing: isEditing,
    status: status ?? this.status,
    createdAt: createdAt,
    title: title ?? this.title,
    note: note ?? this.note,
    date: date ?? this.date,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    participantIds: participantIds ?? this.participantIds,
    payerId: clearPayer ? null : (payerId ?? this.payerId),
    splitType: splitType ?? this.splitType,
    inputMode: inputMode ?? this.inputMode,
    manualTotal: manualTotal ?? this.manualTotal,
    items: items ?? this.items,
    percentBp: percentBp ?? this.percentBp,
    weights: weights ?? this.weights,
    exactAmounts: exactAmounts ?? this.exactAmounts,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    service: service ?? this.service,
    tip: tip ?? this.tip,
    surchargeAlloc: surchargeAlloc ?? this.surchargeAlloc,
    roundingUnit: roundingUnit ?? this.roundingUnit,
    roundingMode: roundingMode ?? this.roundingMode,
  );

  @override
  String toString() =>
      'BillFormState($title, $participantCount người, subtotal=$subtotal)';
}
