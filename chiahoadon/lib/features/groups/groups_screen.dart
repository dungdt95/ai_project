import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/avatar_color.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/member.dart';
import '../../domain/models/member_group.dart';
import '../members/members_provider.dart';
import 'group_form_screen.dart';
import 'groups_provider.dart';

/// S08 — Danh sách nhóm (SPEC FR-2).
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const GroupsScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GroupFormScreen.push(context),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Tạo nhóm'),
      ),
      body: switch (groups) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        AsyncData(:final value) => value.isEmpty
            ? EmptyState(
                icon: Icons.groups_outlined,
                title: 'Chưa có nhóm nào',
                message: 'Nhóm giúp chọn nhanh người tham gia. Hữu ích khi '
                    'bạn hay đi ăn cùng một nhóm bạn.',
                actionLabel: 'Tạo nhóm',
                onAction: () => GroupFormScreen.push(context),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.s16,
                  AppTheme.s16,
                  AppTheme.s16,
                  88,
                ),
                itemCount: value.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.s12),
                itemBuilder: (context, index) =>
                    _GroupCard(group: value[index]),
              ),
      },
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final MemberGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allMembers = ref.watch(membersProvider).value ?? const <Member>[];
    final members = allMembers
        .where((member) => group.memberIds.contains(member.id))
        .toList();

    return Slidable(
      key: ValueKey(group.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => GroupFormScreen.push(context, group: group),
            icon: Icons.edit_outlined,
            label: 'Sửa',
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref),
            icon: Icons.delete_outline,
            label: 'Xóa',
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: () => GroupFormScreen.push(context, group: group),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AvatarColor.fromStored(group.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTheme.s8),
                    Expanded(
                      child: Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${group.memberCount} người',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (group.description != null &&
                    group.description!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.s4),
                  Text(
                    group.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (members.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.s12),
                  Row(
                    children: [
                      MemberAvatarStack(
                        names: [
                          for (final member in members) member.displayName,
                        ],
                        colors: [
                          for (final member in members) member.avatarColor,
                        ],
                      ),
                      const SizedBox(width: AppTheme.s12),
                      Expanded(
                        child: Text(
                          members
                              .map((member) => member.displayName)
                              .join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa nhóm ${group.name}?',
      message: 'Các hóa đơn đã lưu của nhóm này vẫn giữ nguyên. '
          'Chỉ lối tắt chọn nhanh bị xóa.',
      confirmLabel: 'Xóa',
      isDestructive: true,
    );
    if (!context.mounted || !confirmed) return;

    final result = await ref.read(groupsProvider.notifier).delete(group.id);
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(context, 'Đã xóa nhóm ${group.name}'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}
