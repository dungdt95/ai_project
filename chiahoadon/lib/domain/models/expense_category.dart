/// Danh mục hóa đơn (SPEC FR-9.4).
///
/// Đặt tên `ExpenseCategory` thay vì `Category` để không trùng với
/// `Category` của thư viện chuẩn Dart khi import cùng lúc.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    this.sortOrder = 0,
    this.isBuiltin = false,
  });

  factory ExpenseCategory.fromMap(Map<String, Object?> map) => ExpenseCategory(
    id: map['id']! as String,
    name: map['name']! as String,
    icon: map['icon'] as String?,
    color: map['color']! as int,
    sortOrder: map['sort_order']! as int,
    isBuiltin: (map['is_builtin']! as int) == 1,
  );

  final String id;
  final String name;

  /// Emoji hoặc tên icon Material.
  final String? icon;

  final int color;
  final int sortOrder;

  /// Danh mục mặc định do app tạo — không cho xóa, chỉ cho đổi tên.
  final bool isBuiltin;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'sort_order': sortOrder,
    'is_builtin': isBuiltin ? 1 : 0,
  };

  ExpenseCategory copyWith({
    String? name,
    String? icon,
    int? color,
    int? sortOrder,
  }) => ExpenseCategory(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    isBuiltin: isBuiltin,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseCategory && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'ExpenseCategory($id, $name)';
}
