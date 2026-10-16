/// Một người dùng một món, kèm **số phần** người đó dùng (SPEC FR-4.2).
///
/// Giá ghi trên món là giá một phần, nên số phần nhân thẳng vào giá: "Bình
/// uống 2 lon bia, An 1 lon" → Bình trả gấp đôi An.
///
/// Vẫn lưu dạng phân số `num/den` vì cột đã có từ lược đồ v1 và không bao giờ
/// xóa cột (PLAN §4.5); giao diện luôn ghi mẫu số bằng 1.
class ItemParticipant {
  const ItemParticipant({
    required this.memberId,
    this.weightNum = 1,
    this.weightDen = 1,
  });

  factory ItemParticipant.fromMap(Map<String, Object?> map) => ItemParticipant(
    memberId: map['member_id']! as String,
    weightNum: map['weight_num']! as int,
    weightDen: map['weight_den']! as int,
  );

  final String memberId;
  final int weightNum;
  final int weightDen;

  /// Số phần, quy về số nguyên.
  ///
  /// Giá là giá một phần nên nửa phần không còn ý nghĩa; mẫu số chỉ còn để
  /// đọc được dữ liệu cũ. Mẫu số 0 là dữ liệu hỏng — trả 0 thay vì ném lỗi
  /// chia cho 0, để validator kịp báo lỗi cho người dùng.
  int get portions => switch (weightDen) {
    0 => 0,
    1 => weightNum,
    _ => weightNum ~/ weightDen,
  };

  bool get isDefaultWeight => weightNum == 1 && weightDen == 1;

  Map<String, Object?> toMap(String itemId) => {
    'item_id': itemId,
    'member_id': memberId,
    'weight_num': weightNum,
    'weight_den': weightDen,
  };

  ItemParticipant copyWith({int? weightNum, int? weightDen}) =>
      ItemParticipant(
        memberId: memberId,
        weightNum: weightNum ?? this.weightNum,
        weightDen: weightDen ?? this.weightDen,
      );

  @override
  bool operator ==(Object other) =>
      other is ItemParticipant &&
      other.memberId == memberId &&
      other.weightNum == weightNum &&
      other.weightDen == weightDen;

  @override
  int get hashCode => Object.hash(memberId, weightNum, weightDen);
}

/// Một dòng món trong hóa đơn (SPEC FR-3.6).
class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.sortOrder = 0,
    this.participants = const [],
  });

  factory BillItem.fromMap(
    Map<String, Object?> map, {
    List<ItemParticipant> participants = const [],
  }) => BillItem(
    id: map['id']! as String,
    name: map['name']! as String,
    unitPrice: map['unit_price']! as int,
    quantity: map['quantity']! as int,
    sortOrder: map['sort_order']! as int,
    participants: participants,
  );

  final String id;
  final String name;

  /// Đơn giá, đơn vị đồng.
  final int unitPrice;

  /// Số lượng — **không còn dùng tới**.
  ///
  /// Giữ lại cột để đọc được hóa đơn cũ; số lượng giờ nằm ở từng người dưới
  /// dạng số phần, vì cùng một món hai người có thể gọi khác số phần nhau.
  /// Không bao giờ xóa cột khỏi lược đồ (PLAN §4.5).
  final int quantity;

  final int sortOrder;

  /// Những người dùng món này. Rỗng nghĩa là món chung: split engine tính mỗi
  /// người tham gia hóa đơn một phần và UI hiện cảnh báo (FR-4.2).
  final List<ItemParticipant> participants;

  /// Tổng số phần của món.
  ///
  /// Chưa chọn ai thì trả 0 — thành tiền lúc đó phụ thuộc số người tham gia
  /// hóa đơn, mà bản ghi món không biết con số ấy. Dùng [amountFor] ở những
  /// chỗ có đủ thông tin.
  int get portions => participants.fold(0, (sum, p) => sum + p.portions);

  /// Thành tiền của món: đơn giá × số phần.
  ///
  /// Giá ghi trên món là giá **một phần**, nên hai người ăn là hai lần giá đó
  /// (SPEC FR-4.2).
  int get amount => unitPrice * portions;

  /// Thành tiền, có tính cả trường hợp món chung chưa chọn ai.
  int amountFor(int billParticipantCount) =>
      participants.isEmpty ? unitPrice * billParticipantCount : amount;

  /// Món chưa chọn ai dùng — cần hiện nhãn cảnh báo vàng trên UI.
  bool get hasNoParticipants => participants.isEmpty;

  bool get hasCustomWeights =>
      participants.any((p) => !p.isDefaultWeight);

  bool includes(String memberId) =>
      participants.any((p) => p.memberId == memberId);

  Map<String, Object?> toMap(String billId) => {
    'id': id,
    'bill_id': billId,
    'name': name,
    'unit_price': unitPrice,
    'quantity': quantity,
    'amount': amount,
    'sort_order': sortOrder,
  };

  BillItem copyWith({
    String? name,
    int? unitPrice,
    int? quantity,
    int? sortOrder,
    List<ItemParticipant>? participants,
  }) => BillItem(
    id: id,
    name: name ?? this.name,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    sortOrder: sortOrder ?? this.sortOrder,
    participants: participants ?? this.participants,
  );

  @override
  String toString() =>
      'BillItem($name, $unitPrice × $portions phần = $amount)';
}
