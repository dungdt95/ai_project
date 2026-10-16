import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/money_field.dart';
import '../../domain/models/item_preset.dart';
import 'item_presets_provider.dart';

/// Quản lý danh sách món đặt sẵn tên và giá.
///
/// Khai báo một lần những món nhóm hay gọi, để khi nhập hóa đơn chỉ cần chọn
/// thay vì gõ lại tên và giá.
class ItemPresetsScreen extends ConsumerWidget {
  const ItemPresetsScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const ItemPresetsScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(itemPresetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Món có sẵn')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm món'),
      ),
      body: switch (presets) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(itemPresetsProvider),
        ),
        AsyncData(:final value) => value.isEmpty
            ? const EmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'Chưa có món nào',
                message: 'Thêm những món nhóm hay gọi, lần sau nhập hóa đơn '
                    'chỉ cần chọn.',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: value.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: AppTheme.s16),
                itemBuilder: (context, index) {
                  final preset = value[index];

                  return ListTile(
                    leading: const Icon(Icons.restaurant_menu_outlined),
                    title: Text(preset.name),
                    subtitle: Text(
                      preset.unitPrice == 0
                          ? 'Chưa đặt giá'
                          : preset.unitPrice.toVnd(),
                      style: MoneyTextStyle.small,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Xóa món',
                      onPressed: () => _delete(context, ref, preset),
                    ),
                    onTap: () => _edit(context, ref, preset),
                  );
                },
              ),
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ItemPreset? preset,
  ]) async {
    final input = await ItemPresetSheet.show(context, preset: preset);
    if (input == null || !context.mounted) return;

    final notifier = ref.read(itemPresetsProvider.notifier);
    final result = preset == null
        ? await notifier.create(name: input.name, unitPrice: input.unitPrice)
        : await notifier.save(
            preset,
            name: input.name,
            unitPrice: input.unitPrice,
          );

    if (!context.mounted) return;
    result.when(
      ok: (_) => AppSnackBar.success(
        context,
        preset == null ? 'Đã thêm món' : 'Đã lưu món',
      ),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ItemPreset preset,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa "${preset.name}"?',
      // Nói rõ để người dùng không sợ mất hóa đơn cũ: món trong hóa đơn đã
      // chép lại tên và giá nên không phụ thuộc bản ghi này.
      message: 'Các hóa đơn đã lưu giữ nguyên tên và giá của món, không bị '
          'ảnh hưởng.',
      confirmLabel: 'Xóa',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(itemPresetsProvider.notifier).delete(preset.id);
    if (context.mounted) AppSnackBar.success(context, 'Đã xóa món');
  }
}

/// Dữ liệu người dùng nhập ở sheet thêm/sửa món.
typedef ItemPresetInput = ({String name, int unitPrice});

/// Sheet thêm hoặc sửa một món có sẵn.
class ItemPresetSheet extends StatefulWidget {
  const ItemPresetSheet({super.key, this.preset, this.initialName});

  final ItemPreset? preset;

  /// Điền sẵn tên, dùng khi lưu nhanh từ màn nhập hóa đơn.
  final String? initialName;

  static Future<ItemPresetInput?> show(
    BuildContext context, {
    ItemPreset? preset,
    String? initialName,
  }) => showModalBottomSheet<ItemPresetInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        ItemPresetSheet(preset: preset, initialName: initialName),
  );

  @override
  State<ItemPresetSheet> createState() => _ItemPresetSheetState();
}

class _ItemPresetSheetState extends State<ItemPresetSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  int _unitPrice = 0;

  @override
  void initState() {
    super.initState();

    final preset = widget.preset;
    if (preset != null) {
      _nameController.text = preset.name;
      _unitPrice = preset.unitPrice;
      _priceController.text = preset.unitPrice == 0
          ? ''
          : preset.unitPrice.toVndPlain();
    } else if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _nameController.text.trim().isNotEmpty;

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
            widget.preset == null ? 'Thêm món' : 'Sửa món',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.s16),

          TextField(
            controller: _nameController,
            autofocus: widget.preset == null && widget.initialName == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên món *',
              hintText: 'Lẩu thái',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTheme.s12),

          MoneyField(
            controller: _priceController,
            label: 'Giá một người',
            onChanged: (value) => setState(() => _unitPrice = value),
          ),
          const SizedBox(height: AppTheme.s8),
          Text(
            'Giá cho **một người**. Lúc nhập hóa đơn, app nhân với số người '
            'dùng món. Để trống nếu giá hay thay đổi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.s24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave
                  ? () => Navigator.of(context).pop((
                      name: _nameController.text,
                      unitPrice: _unitPrice,
                    ))
                  : null,
              child: const Text('Lưu món'),
            ),
          ),
        ],
      ),
    );
  }
}
