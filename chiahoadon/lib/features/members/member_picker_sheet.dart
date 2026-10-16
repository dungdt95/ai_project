import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vn_text.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_chip.dart';
import '../../domain/models/member.dart';
import '../groups/groups_provider.dart';
import 'member_form_screen.dart';
import 'members_provider.dart';

/// Bộ chọn nhiều thành viên.
///
/// Dùng ở form nhóm (SPEC FR-2.1) và ở bước chọn người tham gia hóa đơn
/// (SPEC FR-3.2). Có nút chọn cả nhóm và chọn tất cả, vì mục tiêu G1 là nhập
/// xong một hóa đơn chia đều trong dưới 30 giây.
///
/// Trả về tập id đã chọn, hoặc `null` nếu người dùng đóng sheet mà không lưu.
class MemberPickerSheet extends ConsumerStatefulWidget {
  const MemberPickerSheet({
    required this.initialSelection,
    super.key,
    this.title = 'Chọn thành viên',
    this.showGroupShortcuts = true,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> initialSelection,
    String title = 'Chọn thành viên',
    bool showGroupShortcuts = true,
  }) => showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => MemberPickerSheet(
      initialSelection: initialSelection,
      title: title,
      showGroupShortcuts: showGroupShortcuts,
    ),
  );

  final Set<String> initialSelection;
  final String title;

  /// Hiện các nút chọn nhanh theo nhóm đã lưu.
  final bool showGroupShortcuts;

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(selectableMembersProvider);
    final groups = ref.watch(groupsProvider).value ?? const [];

    final visible = _query.trim().isEmpty
        ? all
        : all
              .where(
                (member) =>
                    VnText.contains(member.name, _query) ||
                    VnText.contains(member.nickname ?? '', _query),
              )
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.s16,
              AppTheme.s16,
              AppTheme.s8,
              AppTheme.s8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Đã chọn ${_selected.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (all.length > 6)
            Padding
            (
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),

          if (all.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.s16,
                vertical: AppTheme.s12,
              ),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 18),
                    label: const Text('Tất cả'),
                    onPressed: () => setState(
                      () => _selected = all.map((m) => m.id).toSet(),
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.s8),
                    ActionChip(
                      avatar: const Icon(Icons.clear, size: 18),
                      label: const Text('Bỏ hết'),
                      onPressed: () => setState(_selected.clear),
                    ),
                  ],
                  if (widget.showGroupShortcuts)
                    for (final group in groups) ...[
                      const SizedBox(width: AppTheme.s8),
                      ActionChip(
                        avatar: const Icon(Icons.group, size: 18),
                        label: Text('${group.name} (${group.memberCount})'),
                        onPressed: () => setState(
                          () => _selected = {...group.memberIds},
                        ),
                      ),
                    ],
                ],
              ),
            ),

          Expanded(
            child: all.isEmpty
                ? EmptyState(
                    icon: Icons.group_outlined,
                    title: 'Chưa có thành viên nào',
                    message: 'Thêm thành viên trước khi chia hóa đơn.',
                    actionLabel: 'Thêm thành viên',
                    onAction: () => MemberFormScreen.push(context),
                  )
                : visible.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'Không tìm thấy ai',
                  )
                : ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.s16,
                      0,
                      AppTheme.s16,
                      AppTheme.s16,
                    ),
                    children: [
                      Wrap(
                        spacing: AppTheme.s8,
                        runSpacing: AppTheme.s8,
                        children: [
                          for (final member in visible)
                            MemberChip(
                              member: member,
                              selected: _selected.contains(member.id),
                              onTap: () => _toggle(member),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),

          SafeArea(
            minimum: const EdgeInsets.all(AppTheme.s16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      _selected.isEmpty
                          ? 'Xong'
                          : 'Xong (${_selected.length})',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(Member member) => setState(() {
    if (!_selected.remove(member.id)) _selected.add(member.id);
  });
}
