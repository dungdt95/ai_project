/// Named `ProductCategory` (not `Category`) to avoid clashing with
/// Flutter's own `Category` annotation class exported via foundation.dart.
class ProductCategory {
  final int? id;
  final String name;

  const ProductCategory({this.id, required this.name});

  ProductCategory copyWith({int? id, String? name}) {
    return ProductCategory(id: id ?? this.id, name: name ?? this.name);
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'name': name};
  }

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(id: map['id'] as int, name: map['name'] as String);
  }
}
