class Category {
  final int? id;
  final String name;
  final String type; // 'income' | 'expense'
  final String icon;
  final String color;
  final bool isDefault;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: m['icon'] as String? ?? 'category',
        color: m['color'] as String? ?? '#9E9E9E',
        isDefault: (m['is_default'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'is_default': isDefault ? 1 : 0,
      };

  Category copyWith({int? id, String? name, String? type, String? icon, String? color, bool? isDefault}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isDefault: isDefault ?? this.isDefault,
      );
}
