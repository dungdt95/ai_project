import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/money_field.dart';
import '../../domain/models/member.dart';
import '../../domain/settlement/debt_simplifier.dart';
import '../../domain/stats/stats_models.dart';
import '../members/members_provider.dart';
import 'settlement_provider.dart';
import 'transfer_qr_sheet.dart';

/// S10 — Quyết toán: ai nợ ai, và cách trả ít giao dịch nhất (SPEC FR-6).
class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const SettlementScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(settlementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quyết toán')),
      body: switch (view) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(settlementProvider),
        ),
        AsyncData(:final value) => value.isSettled && value.payments.isEmpty
            ? const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'Không ai nợ ai',
                message: 'Mọi hóa đơn đều đã được trả xong.',
              )
            : _Content(view: value),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecordPaymentSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Ghi nhận chuyển tiền'),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.view});

  final SettlementView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in members) member.id: member};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.s16,
        AppTheme.s16,
        AppTheme.s16,
        88,
      ),
      children: [
        // Bất biến của hệ thống. Nếu vỡ thì có hóa đơn ghi sai, và gợi ý
        // chuyển tiền bên dưới sẽ không đưa mọi người về 0 (SPEC FR-6.4).
        if (!view.isConsistent)
          Card(
            color: AppColors.warningBg,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.s16),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningFg,
                  ),
                  const SizedBox(width: AppTheme.s12),
                  Expanded(
                    child: Text(
                      'Tổng số dư đang lệch ${view.balanceSum.toVnd()}. '
                      'Có hóa đơn ghi chưa đúng.',
                      style: const TextStyle(color: AppColors.warningFg),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (view.balances.isNotEmpty) ...[
          Text(
            'SỐ DƯ RÒNG',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.s8),
          Card(
            child: Column(
              children: [
                for (final balance in view.balances)
                  _BalanceRow(balance: balance, member: byId[balance.memberId]),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.s24),
        ],

        if (view.transfers.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.s8),
              Expanded(
                child: Text(
                  'GỢI Ý: ${view.transfers.length} giao dịch là đủ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          for (final transfer in view.transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.s8),
              child: _TransferCard(transfer: transfer, members: byId),
            ),
          const SizedBox(height: AppTheme.s24),
        ],

        if (view.payments.isNotEmpty) ...[
          Text(
            'ĐÃ CHUYỂN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.s8),
          Card(
            child: Column(
              children: [
                for (final payment in view.payments)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(
                      '${byId[payment.fromMemberId]?.displayName ?? '?'}'
                      ' → ${byId[payment.toMemberId]?.displayName ?? '?'}',
                    ),
                    subtitle: Text(
                      DateFormatter.relative(
                        DateTime.fromMillisecondsSinceEpoch(payment.paidAt),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          payment.amount.toVnd(),
                          style: MoneyTextStyle.small,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Xóa ghi nhận',
                          onPressed: () => _deletePayment(context, ref, payment.id),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _deletePayment(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Xóa ghi nhận này?',
      message: 'Số dư của hai người sẽ được tính lại.',
      confirmLabel: 'Xóa',
      isDestructive: true,
    );
    if (!context.mounted || !confirmed) return;

    final result = await ref
        .read(settlementProvider.notifier)
        .deletePayment(id);
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(context, 'Đã xóa ghi nhận'),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance, this.member});

  final MemberBalance balance;
  final Member? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member?.displayName ?? balance.memberName;

    return ListTile(
      leading: MemberAvatar(
        name: name,
        color: member?.avatarColor,
        isSelf: member?.isSelf ?? false,
      ),
      title: Text(name),
      subtitle: Text(
        balance.isCreditor ? 'được nhận' : 'cần trả',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        balance.balance.toVndSigned(),
        style: MoneyTextStyle.medium.copyWith(
          color: balance.isCreditor ? AppColors.creditor : AppColors.debtor,
        ),
      ),
    );
  }
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.transfer, required this.members});

  final SettlementTransfer transfer;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final receiver = members[transfer.toMemberId];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          children: [
            Row(
              children: [
                MemberAvatar.small(
                  name: transfer.fromName,
                  color: members[transfer.fromMemberId]?.avatarColor,
                ),
                const SizedBox(width: AppTheme.s8),
                Expanded(
                  child: Text(
                    transfer.fromName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18),
                const SizedBox(width: AppTheme.s8),
                MemberAvatar.small(
                  name: transfer.toName,
                  color: receiver?.avatarColor,
                ),
                const SizedBox(width: AppTheme.s8),
                Expanded(
                  child: Text(
                    transfer.toName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer.amount.toVnd(),
                    style: MoneyTextStyle.medium.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (receiver != null && receiver.hasBankInfo)
                  IconButton(
                    icon: const Icon(Icons.qr_code_2),
                    tooltip: 'QR chuyển khoản',
                    onPressed: () => TransferQrSheet.show(
                      context,
                      payee: receiver,
                      amount: transfer.amount,
                      note: 'Chia hoa don ',
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => _confirm(context, ref),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Đã chuyển'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
            ),
            if (receiver?.hasBankInfo ?? false)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.s8),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, size: 14),
                    const SizedBox(width: AppTheme.s4),
                    Expanded(
                      child: Text(
                        '${receiver!.bankName ?? ''} '
                        '${receiver.bankAccount}'.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(settlementProvider.notifier)
        .recordPayment(
          fromMemberId: transfer.fromMemberId,
          toMemberId: transfer.toMemberId,
          amount: transfer.amount,
        );
    if (!context.mounted) return;

    result.when(
      ok: (_) => AppSnackBar.success(
        context,
        'Đã ghi nhận ${transfer.fromName} chuyển ${transfer.toName}',
      ),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

/// Ghi nhận một lần chuyển tiền không gắn hóa đơn nào (SPEC FR-6.6).
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const RecordPaymentSheet(),
      );

  @override
  ConsumerState<RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _amountController = TextEditingController();

  String? _fromId;
  String? _toId;
  int _amount = 0;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(selectableMembersProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s16,
        right: AppTheme.s16,
        top: AppTheme.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ghi nhận chuyển tiền',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            Text('Người chuyển', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppTheme.s8),
            _MemberPicker(
              members: members,
              selectedId: _fromId,
              onSelected: (id) => setState(() => _fromId = id),
            ),
            const SizedBox(height: AppTheme.s16),

            Text('Người nhận', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppTheme.s8),
            _MemberPicker(
              members: members,
              selectedId: _toId,
              onSelected: (id) => setState(() => _toId = id),
            ),
            const SizedBox(height: AppTheme.s16),

            MoneyField(
              controller: _amountController,
              label: 'Số tiền',
              onChanged: (value) => setState(() => _amount = value),
            ),
            const SizedBox(height: AppTheme.s24),

            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              child: const Text('Ghi nhận'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _fromId != null && _toId != null && _fromId != _toId && _amount > 0;

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await ref
        .read(settlementProvider.notifier)
        .recordPayment(
          fromMemberId: _fromId!,
          toMemberId: _toId!,
          amount: _amount,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) {
        Navigator.of(context).pop();
        AppSnackBar.success(context, 'Đã ghi nhận chuyển tiền');
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

class _MemberPicker extends StatelessWidget {
  const _MemberPicker({
    required this.members,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Member> members;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.s8,
      runSpacing: AppTheme.s8,
      children: [
        for (final member in members)
          ChoiceChip(
            avatar: MemberAvatar.small(
              name: member.displayName,
              color: member.avatarColor,
            ),
            label: Text(member.displayName),
            selected: selectedId == member.id,
            onSelected: (_) => onSelected(member.id),
          ),
      ],
    );
  }
}
