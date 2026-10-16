import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/models/member.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';
import 'members_provider.dart';
import 'quick_add_members_sheet.dart';

/// S05 — Danh sách thành viên (SPEC FR-1).
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const MembersScreen()),
  );

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(filteredMembersProvider);
    final query = ref.watch(memberQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: ref.read(memberQueryProvider.notifier).set,
              )
            : const Text('Thành viên'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
            onPressed: _toggleSearch,
          ),
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Thêm nhanh nhiều người',
              onPressed: () => QuickAddMembersSheet.show(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MemberFormScreen.push(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Thêm'),
      ),
      body: switch (members) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(membersProvider),
        ),
        AsyncData(:final value) => _buildList(value, query),
      },
    );
  }

  Widget _buildList(List<Member> members, String query) {
    if (members.isEmpty) {
      return query.trim().isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: 'Chưa có thành viên nào',
              message: 'Thêm những người hay đi cùng bạn để bắt đầu '
                  'chia hóa đơn.',
              actionLabel: 'Thêm thành viên',
              onAction: () => MemberFormScreen.push(context),
            )
          : EmptyState(
              icon: Icons.search_off,
              title: 'Không tìm thấy ai',
              message: 'Không có thành viên nào khớp với "$query".',
            );
    }

    final active = members.where((member) => member.isActive).toList();
    final inactive = members.where((member) => !member.isActive).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final member in active) _MemberTile(member: member),
        if (inactive.isNotEmpty) ...[
          const Divider(height: AppTheme.s24),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.s16,
              0,
              AppTheme.s16,
              AppTheme.s8,
            ),
            child: Text(
              'NGỪNG HOẠT ĐỘNG (${inactive.length})',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.s16,
              0,
              AppTheme.s16,
              AppTheme.s12,
            ),
            child: Text(
              'Những người này không hiện khi tạo hóa đơn mới, nhưng vẫn giữ '
              'nguyên trong các hóa đơn cũ.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final member in inactive) _MemberTile(member: member),
        ],
      ],
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        ref.read(memberQueryProvider.notifier).clear();
      }
    });
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle = _subtitle();

    return Slidable(
      key: ValueKey(member.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => MemberFormScreen.push(context, member: member),
            icon: Icons.edit_outlined,
            label: 'Sửa',
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
          ),
          if (member.isActive)
            SlidableAction(
              onPressed: (_) => _confirmDeactivate(context, ref),
              icon: Icons.person_off_outlined,
              label: 'Ẩn',
              backgroundColor: AppColors.partial,
              foregroundColor: Colors.white,
            )
          else
            SlidableAction(
              onPressed: (_) => _reactivate(context, ref),
              icon: Icons.person_add_alt_1_outlined,
              label: 'Bật lại',
              backgroundColor: AppColors.paid,
              foregroundColor: Colors.white,
            ),
        ],
      ),
      child: ListTile(
        leading: MemberAvatar(
          name: member.displayName,
          color: member.avatarColor,
          isSelf: member.isSelf,
          isInactive: !member.isActive,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: member.isActive
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (member.isSelf) ...[
              const SizedBox(width: AppTheme.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tôi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        // Mở chi tiết chứ không mở thẳng form sửa: thứ người dùng muốn xem
        // thường là tổng chi và lịch sử, còn sửa là việc hiếm hơn (FR-7.2).
        onTap: () => MemberDetailScreen.push(context, member),
      ),
    );
  }

  /// Dòng phụ ưu tiên thông tin giúp phân biệt hai người trùng tên.
  String? _subtitle() {
    final parts = <String>[];
    if (member.nickname != null && member.nickname != member.displayName) {
      parts.add(member.name);
    }
    if (member.phone != null) parts.add(member.phone!);
    if (member.hasBankInfo) {
      parts.add(member.bankName ?? 'Đã có số tài khoản');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(membersProvider.notifier);

    final check = await notifier.checkDeletion(member.id);
    if (!context.mounted) return;

    // Người dùng không được xóa bản ghi "Tôi"; repository chặn và giải thích.
    if (check case Err(:final error)) {
      AppSnackBar.error(context, error.message);
      return;
    }

    final info = check.valueOrNull!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: info.canHardDelete
          ? 'Xóa ${member.displayName}?'
          : 'Ẩn ${member.displayName}?',
      message: info.reason,
      confirmLabel: info.canHardDelete ? 'Xóa' : 'Ẩn',
      isDestructive: info.canHardDelete,
    );
    if (!context.mounted || !confirmed) return;

    final result = await notifier.delete(member.id);
    if (!context.mounted) return;

    result.when(
      ok: (outcome) => AppSnackBar.success(
        context,
        outcome == MemberDeletionOutcome.deleted
            ? 'Đã xóa ${member.displayName}'
            : 'Đã ẩn ${member.displayName} khỏi danh sách chọn',
      ),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(membersProvider.notifier)
        .setActive(member.id, isActive: true);
    if (!context.mounted) return;

    result.when(
      ok: (_) =>
          AppSnackBar.success(context, 'Đã bật lại ${member.displayName}'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}
