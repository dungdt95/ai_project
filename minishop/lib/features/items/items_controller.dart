import 'package:flutter/foundation.dart';

import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/item_repository.dart';

class ItemsController extends ChangeNotifier {
  final ItemRepository _itemRepo = ItemRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  List<Item> _items = [];
  List<ProductCategory> _categories = [];
  bool _isLoading = false;

  List<Item> get items => _items;
  List<ProductCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  String categoryName(int? categoryId) {
    if (categoryId == null) return 'Chưa phân loại';
    final match = _categories.where((c) => c.id == categoryId);
    return match.isEmpty ? 'Chưa phân loại' : match.first.name;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _categories = await _categoryRepo.getAll();
    _items = await _itemRepo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await _itemRepo.create(item);
    await load();
  }

  Future<void> updateItem(Item item) async {
    await _itemRepo.update(item);
    await load();
  }

  Future<void> deleteItem(int id) async {
    await _itemRepo.delete(id);
    await load();
  }

  Future<void> addCategory(String name) async {
    await _categoryRepo.create(ProductCategory(name: name));
    await load();
  }

  Future<void> updateCategory(ProductCategory category) async {
    await _categoryRepo.update(category);
    await load();
  }

  Future<void> deleteCategory(int id) async {
    await _categoryRepo.delete(id);
    await load();
  }
}
