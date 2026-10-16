import '../models/bill.dart';
import '../models/enums.dart';
import '../models/surcharge.dart';

/// Giới hạn an toàn cho số tiền.
class SplitLimits {
  const SplitLimits._();

  /// 1 nghìn tỷ đồng. Không phải giới hạn kỹ thuật — toàn bộ phép tính bên
  /// trong dùng [BigInt] nên không tràn số — mà là chốt chặn lỗi gõ máy.
  static const int maxAmount = 1000000000000;

  /// Số người tối đa trong một hóa đơn.
  static const int maxParticipants = 100;
}

/// Một người tham gia, kèm tham số riêng của kiểu chia.
///
/// Chỉ một nhóm trường có nghĩa, tùy [SplitInput.splitType]:
/// - [SplitType.shares] dùng [weightNum] / [weightDen]
/// - [SplitType.percentage] dùng [percentBp]
/// - [SplitType.exact] dùng [exactAmount]
/// - [SplitType.equal] và [SplitType.itemized] không dùng trường nào
class SplitParticipant {
  const SplitParticipant({
    required this.memberId,
    this.weightNum = 1,
    this.weightDen = 1,
    this.percentBp = 0,
    this.exactAmount = 0,
  });

  final String memberId;

  /// Số phần, dạng phân số để biểu diễn được "1,5 phần" = `3/2`.
  final int weightNum;
  final int weightDen;

  /// Tỷ lệ phần trăm dạng basis point: `33,33%` → `3333`.
  final int percentBp;

  /// Số tiền chỉ định, đơn vị đồng.
  final int exactAmount;

  @override
  String toString() => 'SplitParticipant($memberId)';
}

/// Một người dùng một món, kèm trọng số trong món đó.
class SplitItemShare {
  const SplitItemShare({
    required this.memberId,
    this.weightNum = 1,
    this.weightDen = 1,
  });

  final String memberId;

  /// Số phần người này dùng: "Bình uống 2 lon, An 1 lon" → `2/1` và `1/1`.
  final int weightNum;
  final int weightDen;

  /// Số phần, quy về số nguyên.
  ///
  /// Giá là giá **một phần** nên số phần phải là số nguyên — nửa phần thì
  /// không còn là "giá món × số người" nữa. Mẫu số chỉ còn để đọc được dữ
  /// liệu cũ; giao diện luôn ghi mẫu số bằng 1.
  ///
  /// Mẫu số 0 là dữ liệu hỏng: trả 0 thay vì ném lỗi chia cho 0, để validator
  /// kịp báo `invalidWeight` cho người dùng thay vì app đổ ngay tại đây.
  int get portions => switch (weightDen) {
    0 => 0,
    1 => weightNum,
    _ => weightNum ~/ weightDen,
  };

  @override
  String toString() => 'SplitItemShare($memberId, $weightNum/$weightDen)';
}

/// Một món trong hóa đơn, ở dạng tối giản mà engine cần.
///
/// Mang **đơn giá cho một phần**, không mang thành tiền: thành tiền phụ thuộc
/// số người dùng món, mà chỉ engine mới biết đủ danh sách người tham gia hóa
/// đơn để tính ra số đó (SPEC FR-4.2).
class SplitItem {
  const SplitItem({
    required this.id,
    required this.unitPrice,
    this.users = const [],
  });

  final String id;

  /// Giá **một phần**, đơn vị đồng. Hai người ăn là hai phần.
  final int unitPrice;

  /// Những người dùng món này.
  ///
  /// Rỗng nghĩa là món chung: engine tính mỗi người tham gia hóa đơn một phần,
  /// và UI hiện nhãn cảnh báo vàng (SPEC FR-4.2).
  final List<SplitItemShare> users;

  bool get isShared => users.isEmpty;

  /// Tổng số phần của món, trong phạm vi những người còn tham gia hóa đơn.
  ///
  /// Món chung (chưa chọn ai) tính mỗi người tham gia một phần.
  int portions(List<String> billIds) {
    if (users.isEmpty) return billIds.length;

    var total = 0;
    for (final user in users) {
      if (billIds.contains(user.memberId)) total += user.portions;
    }
    return total;
  }

  /// Thành tiền của món: đơn giá × tổng số phần.
  int amountFor(List<String> billIds) => unitPrice * portions(billIds);

  @override
  String toString() => 'SplitItem($id, $unitPrice/phần, ${users.length} người)';
}

/// Toàn bộ đầu vào của split engine.
///
/// Bất biến và **không phụ thuộc cơ sở dữ liệu hay Flutter**, nên
/// `computeSplit` là hàm thuần: cùng đầu vào luôn cho cùng đầu ra, test được
/// bằng `flutter test` mà không cần emulator (PLAN §3.1).
class SplitInput {
  const SplitInput({
    required this.participants,
    required this.splitType,
    this.inputMode = InputMode.total,
    this.manualTotal = 0,
    this.items = const [],
    this.discount = const Surcharge.none(),
    this.tax = const Surcharge.none(),
    this.service = const Surcharge.none(),
    this.tip = 0,
    this.surchargeAlloc = SurchargeAlloc.proportional,
    this.roundingUnit = 1000,
    this.roundingMode = RoundingMode.up,
  });

  /// Dựng đầu vào từ một hóa đơn đã có, để tính lại khi sửa (SPEC FR-3.13).
  factory SplitInput.fromBill(Bill bill) => SplitInput(
    participants: [
      for (final p in bill.participants)
        SplitParticipant(
          memberId: p.memberId,
          weightNum: p.weightNum,
          weightDen: p.weightDen,
          percentBp: p.percentBp,
          exactAmount: p.exactAmount,
        ),
    ],
    splitType: bill.splitType,
    inputMode: bill.inputMode,
    manualTotal: bill.inputMode == InputMode.total ? bill.subtotal : 0,
    items: [
      for (final item in bill.items)
        SplitItem(
          id: item.id,
          unitPrice: item.unitPrice,
          users: [
            for (final u in item.participants)
              SplitItemShare(
                memberId: u.memberId,
                weightNum: u.weightNum,
                weightDen: u.weightDen,
              ),
          ],
        ),
    ],
    discount: bill.discount,
    tax: bill.tax,
    service: bill.service,
    tip: bill.tipAmount,
    surchargeAlloc: bill.surchargeAlloc,
    roundingUnit: bill.roundingUnit,
    roundingMode: bill.roundingMode,
  );

  /// Thứ tự trong danh sách này là thứ tự phá thế đồng hạng khi chia phần dư,
  /// nên kết quả tái lập được (SPEC §FR-5).
  final List<SplitParticipant> participants;

  final SplitType splitType;
  final InputMode inputMode;

  /// Tổng nhập tay, dùng khi [inputMode] là [InputMode.total].
  final int manualTotal;

  /// Danh sách món, dùng khi [inputMode] là [InputMode.items].
  final List<SplitItem> items;

  final Surcharge discount;
  final Surcharge tax;
  final Surcharge service;
  final int tip;
  final SurchargeAlloc surchargeAlloc;

  final int roundingUnit;
  final RoundingMode roundingMode;

  List<String> get participantIds => [
    for (final p in participants) p.memberId,
  ];

  int get participantCount => participants.length;

  /// Tổng tiền trước giảm giá và phụ phí — bước 1 của SPEC §FR-5.
  int get subtotal => inputMode == InputMode.items
      ? items.fold(0, (sum, item) => sum + item.amountFor(participantIds))
      : manualTotal;

  SplitInput copyWith({
    List<SplitParticipant>? participants,
    SplitType? splitType,
    InputMode? inputMode,
    int? manualTotal,
    List<SplitItem>? items,
    Surcharge? discount,
    Surcharge? tax,
    Surcharge? service,
    int? tip,
    SurchargeAlloc? surchargeAlloc,
    int? roundingUnit,
    RoundingMode? roundingMode,
  }) => SplitInput(
    participants: participants ?? this.participants,
    splitType: splitType ?? this.splitType,
    inputMode: inputMode ?? this.inputMode,
    manualTotal: manualTotal ?? this.manualTotal,
    items: items ?? this.items,
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
      'SplitInput(${splitType.dbValue}, $participantCount người, '
      'subtotal=$subtotal)';
}
