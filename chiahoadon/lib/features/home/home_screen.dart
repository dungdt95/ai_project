import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/member.dart';
import '../../domain/stats/stats_models.dart';
import '../bills/bills_provider.dart';
import '../bills/detail/bill_detail_screen.dart';
import '../bills/form/bill_form_screen.dart';
import '../members/members_provider.dart';
import '../settlement/settlement_screen.dart';
import '../stats/stats_provider.dart';

/// S01 — Dashboard (SPEC FR-7.8).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final bills = ref.watch(billListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BillFormScreen.push(context),
        icon: const Icon(Icons.add),
        label: const Text('Tạo hóa đơn'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.s16,
          AppTheme.s16,
          AppTheme.s16,
          88,
        ),
        children: [
          switch (summary) {
            AsyncData(:final value) => _Summary(summary: value),
            AsyncError(:final error) => ErrorView.fromError(error),
            _ => const Center(child: CircularProgressIndicator()),
          },
          const SizedBox(height: AppTheme.s24),

          Text(
            'HÓA ĐƠN GẦN ĐÂY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.s8),

          switch (bills) {
            // Bỏ nháp khỏi đây: nháp chưa có số tiền nên nằm chung với các hóa
            // đơn đã chốt thì chỉ gây hiểu nhầm. Chỗ tìm lại nháp là tab Hóa đơn,
            // nơi mỗi thẻ có nhãn trạng thái.
            AsyncData(:final value) => _finished(value.bills).isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có hóa đơn nào',
                    message: 'Tạo hóa đơn đầu tiên để bắt đầu.',
                  )
                : _RecentBills(bills: _finished(value.bills).take(5).toList()),
            AsyncError(:final error) => ErrorView.fromError(error),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }

  /// Các hóa đơn đã chốt, bỏ nháp ra.
  List<Bill> _finished(List<Bill> bills) =>
      [for (final bill in bills) if (bill.status != BillStatus.draft) bill];
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              children: [
                Text(
                  'Bạn đã chi tháng này',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.s4),
                FittedBox(
                  child: Text(
                    summary.monthTotal.toVnd(),
                    style: MoneyTextStyle.large,
                  ),
                ),
                const SizedBox(height: AppTheme.s4),
                Text(
                  '${summary.monthBillCount} hóa đơn',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        Row(
          children: [
            Expanded(
              child: _MiniTile(
                label: 'NGƯỜI KHÁC NỢ BẠN',
                value: summary.owedToMe.toVnd(),
                accent: AppColors.creditor,
                onTap: () => SettlementScreen.push(context),
              ),
            ),
            const SizedBox(width: AppTheme.s12),
            Expanded(
              child: _MiniTile(
                label: 'BẠN ĐANG NỢ',
                value: summary.iOwe.toVnd(),
                accent: AppColors.debtor,
                onTap: () => SettlementScreen.push(context),
              ),
            ),
          ],
        ),
        if (summary.unsettledBillCount > 0) ...[
          const SizedBox(height: AppTheme.s12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(
                '${summary.unsettledBillCount} hóa đơn chưa trả xong',
              ),
              subtitle: const Text('Xem gợi ý chuyển tiền'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => SettlementScreen.push(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppTheme.s4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: MoneyTextStyle.medium.copyWith(color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentBills extends ConsumerWidget {
  const _RecentBills({required this.bills});

  final List<Bill> bills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in members) member.id: member};

    return Card(
      child: Column(
        children: [
          for (final bill in bills)
            ListTile(
              leading: MemberAvatarStack(
                names: [
                  for (final p in bill.participants)
                    byId[p.memberId]?.displayName ?? p.memberNameSnapshot,
                ],
                colors: [
                  for (final p in bill.participants)
                    byId[p.memberId]?.avatarColor ?? 0xFF9CA3AF,
                ],
                size: 24,
                maxVisible: 3,
              ),
              title: Text(bill.title, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                DateFormatter.short(
                  DateTime.fromMillisecondsSinceEpoch(bill.billDate),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Text(
                bill.totalAmount.toVnd(),
                style: MoneyTextStyle.small,
              ),
              onTap: () => BillDetailScreen.push(context, bill.id),
            ),
        ],
      ),
    );
  }
}

