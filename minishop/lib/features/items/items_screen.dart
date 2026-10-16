import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/item.dart';
import 'categories_screen.dart';
import 'items_controller.dart';
import 'widgets/item_form_dialog.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ItemsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mặt hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Quản lý danh mục',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.load,
              child: controller.items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                            child:
                                Text('Chưa có mặt hàng nào. Bấm + để thêm.')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: controller.items.length,
                      itemBuilder: (context, index) {
                        final item = controller.items[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: item.isActive ? null : Colors.grey,
                              decoration: item.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            '${controller.categoryName(item.categoryId)} · ${formatVnd(item.price)} / ${item.unit}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) =>
                                _onMenuSelected(value, item, controller),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Sửa')),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(item.isActive
                                    ? 'Ẩn (ngừng bán)'
                                    : 'Hiện lại'),
                              ),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Xóa')),
                            ],
                          ),
                          onTap: () => _editItem(item, controller),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(controller),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onMenuSelected(
    String value,
    Item item,
    ItemsController controller,
  ) async {
    switch (value) {
      case 'edit':
        await _editItem(item, controller);
        break;
      case 'toggle':
        await controller.updateItem(item.copyWith(isActive: !item.isActive));
        break;
      case 'delete':
        await _deleteItem(item, controller);
        break;
    }
  }

  Future<void> _addItem(ItemsController controller) async {
    final result = await showDialog<Item>(
      context: context,
      builder: (_) => ItemFormDialog(categories: controller.categories),
    );
    if (result != null) {
      await controller.addItem(result);
    }
  }

  Future<void> _editItem(Item item, ItemsController controller) async {
    final result = await showDialog<Item>(
      context: context,
      builder: (_) =>
          ItemFormDialog(existing: item, categories: controller.categories),
    );
    if (result != null) {
      await controller.updateItem(result);
    }
  }

  Future<void> _deleteItem(Item item, ItemsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa mặt hàng'),
        content: Text('Xóa "${item.name}"? Hành động này không thể hoàn tác.'),
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
    if (confirmed == true && item.id != null) {
      await controller.deleteItem(item.id!);
    }
  }
}
