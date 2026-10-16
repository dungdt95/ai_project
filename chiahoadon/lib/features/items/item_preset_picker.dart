import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../domain/models/item_preset.dart';
import 'item_presets_provider.dart';
import 'item_presets_screen.dart';

/// Chọn một món từ danh sách đã đặt sẵn (dùng ở sheet nhập món).
///
/// Trả về món đã chọn, hoặc `null` nếu người dùng đóng sheet.
class ItemPresetPicker extends ConsumerStatefulWidget {
  const ItemPresetPicker({super.key});

  static Future<ItemPreset?> show(BuildContext context) =>
      showModalBottomSheet<ItemPreset>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const ItemPresetPicker(),
      );

  @override
  ConsumerState<ItemPresetPicker> createState() => _ItemPresetPickerState();
}

class _ItemPresetPickerState extends ConsumerState<ItemPresetPicker> {
  final _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Lọc ngay trong bộ nhớ thay vì hỏi lại DB theo từng ký tự.
  ///
  /// Danh sách món của một nhóm bạn hiếm khi quá vài chục dòng, nên lọc tại
  /// chỗ vừa đủ nhanh mà khung kết quả không nhấp nháy khi gõ.
  List<ItemPreset> _filter(List<ItemPreset> all) {
    if (_query.trim().isEmpty) return all;
    return [
      for (final preset in all)
        if (preset.matches(_query)) preset,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(itemPresetsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          AppBar(
            title: const Text('Chọn món'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.s16,
              0,
              AppTheme.s16,
              AppTheme.s8,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm món',
              ),
            ),
          ),
          Expanded(
            child: switch (presets) {
              AsyncLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              AsyncError(:final error) => ErrorView.fromError(error),
              AsyncData(:final value) => _Results(
                presets: _filter(value),
                hasAny: value.isNotEmpty,
                query: _query,
                scrollController: scrollController,
                onAdd: _addNew,
              ),
            },
          ),
        ],
      ),
    );
  }

  /// Thêm món mới ngay tại đây rồi chọn luôn.
  ///
  /// Không bắt người dùng thoát ra vào màn quản lý rồi quay lại: lúc này họ
  /// đang nhập dở một hóa đơn.
  Future<void> _addNew() async {
    final input = await ItemPresetSheet.show(
      context,
      initialName: _query.trim().isEmpty ? null : _query.trim(),
    );
    if (input == null || !mounted) return;

    final result = await ref
        .read(itemPresetsProvider.notifier)
        .create(name: input.name, unitPrice: input.unitPrice);
    if (!mounted) return;

    result.when(
      ok: (preset) => Navigator.of(context).pop(preset),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

/// Danh sách kết quả, hoặc lời mời thêm món khi chưa có gì.
class _Results extends StatelessWidget {
  const _Results({
    required this.presets,
    required this.hasAny,
    required this.query,
    required this.scrollController,
    required this.onAdd,
  });

  final List<ItemPreset> presets;

  /// Danh sách gốc có món nào không — để phân biệt "chưa khai báo món nào" với
  /// "có món nhưng không khớp từ khóa". Hai chuyện đó cần hai lời nhắc khác nhau.
  final bool hasAny;

  final String query;
  final ScrollController scrollController;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: hasAny ? Icons.search_off : Icons.restaurant_menu_outlined,
            title: hasAny ? 'Không tìm thấy món' : 'Chưa có món nào',
            message: hasAny
                ? 'Không có món nào khớp "$query".'
                : 'Thêm những món nhóm hay gọi để lần sau chỉ cần chọn.',
          ),
          const SizedBox(height: AppTheme.s8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Thêm món'),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: presets.length + 1,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: AppTheme.s16),
      itemBuilder: (context, index) {
        if (index == presets.length) {
          return ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Thêm món mới'),
            onTap: onAdd,
          );
        }

        final preset = presets[index];
        return ListTile(
          leading: const Icon(Icons.restaurant_menu_outlined),
          title: Text(preset.name),
          trailing: Text(
            preset.unitPrice == 0 ? '—' : preset.unitPrice.toVnd(),
            style: MoneyTextStyle.small,
          ),
          onTap: () => Navigator.of(context).pop(preset),
        );
      },
    );
  }
}
