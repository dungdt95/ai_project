import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../domain/models/bill.dart';
import '../../../domain/models/bill_filter.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/member.dart';
import '../../members/members_provider.dart';
import '../bills_provider.dart';
import '../detail/bill_detail_screen.dart';
import '../form/bill_form_screen.dart';

/// S02 — Danh sách hóa đơn (SPEC FR-3.11, FR-3.12).
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  /// Khóa của thanh lọc cuộn ngang, dùng trong widget test.
  static const String filterBarKey = 'bill-filter-bar';

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Tải thêm khi còn cách đáy 400px, để danh sách không bị khựng (NFR-3).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(billListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(billListProvider);
    final allMembers = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in allMembers) member.id: member};

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm hóa đơn...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: ref.read(billFilterProvider.notifier).setQuery,
              )
            : const Text('Hóa đơn'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
            onPressed: _toggleSearch,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: _FilterBar(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BillFormScreen.push(context),
        icon: const Icon(Icons.add),
        label: const Text('Tạo hóa đơn'),
      ),
      body: switch (list) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(billListProvider),
        ),
        AsyncData(:final value) => _buildList(value, byId),
      },
    );
  }

  Widget _buildList(BillListState state, Map<String, Member> members) {
    if (state.bills.isEmpty) {
      return ref.read(billFilterProvider).isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Chưa có hóa đơn nào',
              message: 'Tạo hóa đơn đầu tiên để bắt đầu chia tiền với nhóm.',
            )
          : EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Không có hóa đơn nào khớp',
              message: 'Thử bỏ bớt điều kiện lọc.',
              actionLabel: 'Bỏ lọc',
              onAction: ref.read(billFilterProvider.notifier).clear,
            );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.s16,
        AppTheme.s12,
        AppTheme.s16,
        88,
      ),
      itemCount: state.bills.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.s12),
      itemBuilder: (context, index) {
        if (index >= state.bills.length) {
          return const Padding(
            padding: EdgeInsets.all(AppTheme.s16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _BillCard(bill: state.bills[index], members: members);
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        ref.read(billFilterProvider.notifier).setQuery('');
      }
    });
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(billFilterProvider);
    final notifier = ref.read(billFilterProvider.notifier);

    return SizedBox(
      height: 52,
      child: ListView(
        // Khóa để test kéo đúng thanh lọc, thay vì đoán xem Scrollable nào là
        // thanh lọc và Scrollable nào là danh sách hóa đơn.
        key: const Key(BillsScreen.filterBarKey),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
        children: [
          for (final range in DateRangeFilter.values) ...[
            FilterChip(
              label: Text(range.label),
              selected: _isRangeSelected(current, range),
              onSelected: (_) => notifier.setRange(range),
            ),
            const SizedBox(width: AppTheme.s8),
          ],
          const VerticalDivider(width: AppTheme.s16),
          for (final status in [
            BillStatus.unpaid,
            BillStatus.partial,
            BillStatus.settled,
          ]) ...[
            FilterChip(
              label: Text(status.label),
              selected: current.statuses.contains(status),
              onSelected: (_) => notifier.toggleStatus(status),
            ),
            const SizedBox(width: AppTheme.s8),
          ],
          if (current.activeCount > 0)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: const Text('Bỏ lọc'),
              onPressed: notifier.clear,
            ),
        ],
      ),
    );
  }

  bool _isRangeSelected(BillFilter current, DateRangeFilter range) {
    final applied = range.apply(current);
    return applied.range == current.range;
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({required this.bill, required this.members});

  final Bill bill;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = [
      for (final p in bill.participants)
        members[p.memberId]?.displayName ?? p.memberNameSnapshot,
    ];
    final colors = [
      for (final p in bill.participants)
        members[p.memberId]?.avatarColor ?? 0xFF9CA3AF,
    ];

    return Card(
      child: InkWell(
        // Nháp mở thẳng lại form để nhập tiếp; mở màn xem chi tiết thì người
        // dùng không có đường nào quay lại hoàn tất nó (SPEC FR-3.10).
        onTap: () => bill.status == BillStatus.draft
            ? BillFormScreen.push(context, bill: bill)
            : BillDetailScreen.push(context, bill.id),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bill.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.s8),
                  Text(bill.totalAmount.toVnd(), style: MoneyTextStyle.medium),
                ],
              ),
              const SizedBox(height: AppTheme.s4),
              Row(
                children: [
                  // Ngày ghi đủ ngày/tháng/năm chứ không chỉ "3 ngày trước":
                  // danh sách này là chỗ tra lại hóa đơn cũ, mà "3 ngày trước"
                  // thì không đối chiếu được với bất cứ thứ gì.
                  //
                  // Phần ngày và số người co lại khi cần, để nhãn trạng thái
                  // bên phải luôn đọc được trên màn hình hẹp (NFR-9).
                  Expanded(
                    child: Text(
                      '${DateFormatter.short(DateTime.fromMillisecondsSinceEpoch(bill.billDate))}'
                      ' · ${bill.participantCount} người',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.s8),
                  _StatusDot(status: bill.status),
                ],
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: AppTheme.s12),
                MemberAvatarStack(names: names, colors: colors),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BillStatus.draft => AppColors.neutral,
      BillStatus.unpaid => AppColors.unpaid,
      BillStatus.partial => AppColors.partial,
      BillStatus.settled => AppColors.paid,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.s4),
        Text(
          status.label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
