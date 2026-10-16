import '../../core/utils/vn_text.dart';
import 'bill_item.dart';

/// Một món đã đặt sẵn tên và giá, để chọn lại khi nhập hóa đơn.
///
/// Dùng khi nhóm hay ăn cùng mấy món quen: khai báo một lần, những lần sau chỉ
/// chọn thay vì gõ lại tên và giá.
///
/// **Món trong hóa đơn không trỏ về bản ghi này.** Khi chọn, tên và giá được
/// chép sang `BillItem` — sửa giá trong danh sách món sau đó không làm đổi số
/// tiền của hóa đơn cũ, đúng nguyên tắc đã dùng cho tên thành viên (SPEC §5.2).
class ItemPreset {
  const ItemPreset({
    required this.id,
    required this.name,
    required this.nameNorm,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  factory ItemPreset.fromMap(Map<String, Object?> map) => ItemPreset(
    id: map['id']! as String,
    name: map['name']! as String,
    nameNorm: map['name_norm']! as String,
    unitPrice: map['unit_price']! as int,
    sortOrder: map['sort_order']! as int,
    createdAt: map['created_at']! as int,
    updatedAt: map['updated_at']! as int,
  );

  final String id;
  final String name;

  /// Tên đã bỏ dấu, để tìm kiếm gõ "lau thai" ra "Lẩu thái".
  final String nameNorm;

  /// Đơn giá, đơn vị đồng (NFR-6).
  final int unitPrice;

  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'name_norm': nameNorm,
    'unit_price': unitPrice,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  ItemPreset copyWith({
    String? name,
    String? nameNorm,
    int? unitPrice,
    int? sortOrder,
    int? updatedAt,
  }) => ItemPreset(
    id: id,
    name: name ?? this.name,
    nameNorm: nameNorm ?? this.nameNorm,
    unitPrice: unitPrice ?? this.unitPrice,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Có khớp từ khóa tìm kiếm hay không, bỏ qua dấu.
  bool matches(String query) =>
      nameNorm.contains(VnText.normalize(query.trim()));

  /// Dựng một món của hóa đơn từ bản mẫu này.
  ///
  /// Chép giá trị sang chứ không giữ tham chiếu — xem ghi chú ở đầu lớp.
  BillItem toBillItem({
    required String id,
    required List<String> memberIds,
    int quantity = 1,
    int sortOrder = 0,
  }) => BillItem(
    id: id,
    name: name,
    unitPrice: unitPrice,
    quantity: quantity,
    sortOrder: sortOrder,
    participants: [
      for (final memberId in memberIds) ItemParticipant(memberId: memberId),
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is ItemPreset && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);

  @override
  String toString() => 'ItemPreset($name, $unitPrice)';
}
