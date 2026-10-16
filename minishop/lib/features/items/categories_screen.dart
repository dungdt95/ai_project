import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import 'items_controller.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ItemsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      body: ListView.builder(
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];
          return ListTile(
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editCategory(context, controller, category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      _deleteCategory(context, controller, category),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(context, controller),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addCategory(
      BuildContext context, ItemsController controller) async {
    final name = await _promptName(context, title: 'Thêm danh mục');
    if (name != null && name.trim().isNotEmpty) {
      await controller.addCategory(name.trim());
    }
  }

  Future<void> _editCategory(
    BuildContext context,
    ItemsController controller,
    ProductCategory category,
  ) async {
    final name = await _promptName(
      context,
      title: 'Sửa danh mục',
      initial: category.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      await controller.updateCategory(category.copyWith(name: name.trim()));
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    ItemsController controller,
    ProductCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text(
            'Xóa danh mục "${category.name}"? Mặt hàng thuộc danh mục này sẽ chuyển về "Chưa phân loại".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && category.id != null) {
      await controller.deleteCategory(category.id!);
    }
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
