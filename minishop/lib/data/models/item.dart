class Item {
  final int? id;
  final int? categoryId;
  final String name;
  final int price;
  final String unit;
  final bool isActive;
  final String? imagePath;

  const Item({
    this.id,
    this.categoryId,
    required this.name,
    required this.price,
    this.unit = 'ly',
    this.isActive = true,
    this.imagePath,
  });

  Item copyWith({
    int? id,
    int? categoryId,
    String? name,
    int? price,
    String? unit,
    bool? isActive,
    String? imagePath,
  }) {
    return Item(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'unit': unit,
      'is_active': isActive ? 1 : 0,
      'image_path': imagePath,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int,
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      price: map['price'] as int,
      unit: map['unit'] as String? ?? 'ly',
      isActive: (map['is_active'] as int) == 1,
      imagePath: map['image_path'] as String?,
    );
  }
}
