import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../data/data_providers.dart';
import '../../domain/models/expense_category.dart';

/// Quản lý danh mục hóa đơn (SPEC FR-9.4).
///
/// Bảy danh mục mặc định đổi tên được nhưng **không xóa được**: xóa hết rồi thì
/// không còn gì để chọn khi tạo hóa đơn, và người dùng không có cách nào tạo
/// lại bộ mặc định.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const CategoriesScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
      body: switch (categories) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final category in value)
              ListTile(
                leading: Text(
                  category.icon ?? '📦',
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(category.name),
                subtitle: category.isBuiltin
                    ? const Text('Danh mục mặc định')
                    : null,
                trailing: category.isBuiltin
                    ? const Icon(Icons.edit_outlined, size: 20)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Xóa danh mục',
                        onPressed: () => _delete(context, ref, category),
                      ),
                onTap: () => _edit(context, ref, category),
              ),
          ],
        ),
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ExpenseCategory? category,
  ]) async {
    final result = await _CategorySheet.show(context, category: category);
    if (result == null || !context.mounted) return;

    await ref.read(categoryDaoProvider).save(result);
    ref.invalidate(categoriesProvider);

    if (context.mounted) {
      AppSnackBar.success(
        context,
        category == null ? 'Đã thêm danh mục' : 'Đã lưu danh mục',
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExpenseCategory category,
  ) async {
    final dao = ref.read(categoryDaoProvider);
    final billCount = await dao.countBills(category.id);
    if (!context.mounted) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa danh mục ${category.name}?',
      message: billCount == 0
          ? 'Chưa có hóa đơn nào dùng danh mục này.'
          : '$billCount hóa đơn đang dùng danh mục này. Chúng sẽ chuyển sang '
                '"Chưa phân loại", không mất hóa đơn nào.',
      confirmLabel: 'Xóa',
      isDestructive: true,
    );
    if (!context.mounted || !confirmed) return;

    await dao.delete(category.id);
    ref.invalidate(categoriesProvider);

    if (context.mounted) AppSnackBar.success(context, 'Đã xóa danh mục');
  }
}

/// Sheet thêm hoặc sửa một danh mục.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.category});

  /// Emoji gợi ý — gõ emoji trên bàn phím điện thoại khá phiền, nên cho chọn.
  static const List<String> suggestedIcons = [
    '🍜', '🍺', '☕', '🍰', '🛒', '🚕', '✈️', '🏠',
    '🎮', '🎬', '💊', '🎁', '📚', '⚽', '💡', '📦',
  ];

  final ExpenseCategory? category;

  static Future<ExpenseCategory?> show(
    BuildContext context, {
    ExpenseCategory? category,
  }) => showModalBottomSheet<ExpenseCategory>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CategorySheet(category: category),
  );

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name;
  late String _icon;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _icon = widget.category?.icon ?? '📦';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s16,
        right: AppTheme.s16,
        top: AppTheme.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Sửa danh mục' : 'Thêm danh mục',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.s16),

          TextField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Tên danh mục *',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(AppTheme.s12),
                child: Text(_icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTheme.s16),

          Text('Biểu tượng', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppTheme.s8),
          Wrap(
            spacing: AppTheme.s8,
            runSpacing: AppTheme.s8,
            children: [
              for (final icon in _CategorySheet.suggestedIcons)
                ChoiceChip(
                  label: Text(icon, style: const TextStyle(fontSize: 18)),
                  selected: _icon == icon,
                  onSelected: (_) => setState(() => _icon = icon),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.s24),

          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: Text(_isEditing ? 'Lưu' : 'Thêm'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final existing = widget.category;

    Navigator.of(context).pop(
      existing == null
          ? ExpenseCategory(
              id: const Uuid().v4(),
              name: _name.text.trim(),
              icon: _icon,
              color: AppColors.chartPaletteLight.first.toARGB32(),
              sortOrder: 100,
            )
          : existing.copyWith(name: _name.text.trim(), icon: _icon),
    );
  }
}
