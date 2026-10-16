import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';

final _catRepo = CategoryRepository();
final categoriesProvider = FutureProvider<List<Category>>((ref) => _catRepo.getAll());

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(categoriesProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Danh mục'),
          bottom: const TabBar(tabs: [Tab(text: 'Chi tiêu'), Tab(text: 'Thu nhập')]),
        ),
        body: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi: $e')),
          data: (cats) {
            final expense = cats.where((c) => c.type == 'expense').toList();
            final income = cats.where((c) => c.type == 'income').toList();
            return TabBarView(children: [
              _CatList(cats: expense, onRefresh: () => ref.refresh(categoriesProvider)),
              _CatList(cats: income, onRefresh: () => ref.refresh(categoriesProvider)),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_categories',
          onPressed: () => _showAddDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    String type = 'expense';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Thêm danh mục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Chi tiêu')),
                  ButtonSegment(value: 'income', label: Text('Thu nhập')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSt(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên danh mục', border: OutlineInputBorder()),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await _catRepo.insert(Category(
                  name: name,
                  type: type,
                  icon: 'category',
                  color: '#9E9E9E',
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                ref.refresh(categoriesProvider);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatList extends StatelessWidget {
  final List<Category> cats;
  final VoidCallback onRefresh;
  const _CatList({required this.cats, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.categoryColors[i % AppColors.categoryColors.length].withOpacity(0.2),
              child: Icon(Icons.category,
                  color: AppColors.categoryColors[i % AppColors.categoryColors.length]),
            ),
            title: Text(c.name),
            subtitle: c.isDefault ? const Text('Mặc định', style: TextStyle(fontSize: 11)) : null,
            trailing: c.isDefault
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: 'Xóa danh mục', content: 'Xóa danh mục "${c.name}"?');
                      if (ok) {
                        await _catRepo.delete(c.id!);
                        onRefresh();
                      }
                    },
                  ),
          );
        },
      );
}
