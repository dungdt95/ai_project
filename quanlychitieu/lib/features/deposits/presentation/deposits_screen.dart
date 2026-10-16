import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/repositories/deposit_repository.dart';
import '../../../data/models/bank_deposit.dart';
import 'add_deposit_screen.dart';

final _depRepo = DepositRepository();

final depositsProvider = FutureProvider<List<BankDeposit>>((ref) => _depRepo.getAll());

class DepositsScreen extends ConsumerWidget {
  const DepositsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(depositsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tiền gửi ngân hàng')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (deposits) {
          if (deposits.isEmpty) {
            return const EmptyState(
                message: 'Chưa có sổ tiết kiệm nào',
                icon: Icons.account_balance_outlined);
          }

          final active = deposits.where((d) => d.status == 'active').toList();
          final totalAll = active.fold<double>(0, (s, d) => s + d.amount);

          // Group by bankId
          final grouped = <int, List<BankDeposit>>{};
          for (final d in deposits) {
            grouped.putIfAbsent(d.bankId, () => []).add(d);
          }
          // Sort groups: banks with active deposits first
          final bankIds = grouped.keys.toList()
            ..sort((a, b) {
              final aHasActive = grouped[a]!.any((d) => d.status == 'active') ? 0 : 1;
              final bHasActive = grouped[b]!.any((d) => d.status == 'active') ? 0 : 1;
              return aHasActive.compareTo(bHasActive);
            });

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(depositsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                _TotalCard(total: totalAll, count: active.length),
                const SizedBox(height: 12),
                ...bankIds.map((bankId) {
                  final bankDeposits = grouped[bankId]!;
                  return _BankGroup(
                    deposits: bankDeposits,
                    onChanged: () => ref.refresh(depositsProvider),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_deposits',
        onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddDepositScreen()))
            .then((_) => ref.refresh(depositsProvider)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Tổng tất cả ngân hàng ───────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.depositLight,
        child: ListTile(
          leading: const Icon(Icons.account_balance, color: AppColors.deposit, size: 32),
          title: const Text('Tổng tiền gửi đang hiệu lực'),
          subtitle: Text('$count sổ'),
          trailing: Text(formatCurrency(total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.deposit, fontSize: 16)),
        ),
      );
}

// ─── Nhóm theo ngân hàng ─────────────────────────────────────────────────────

class _BankGroup extends StatelessWidget {
  final List<BankDeposit> deposits;
  final VoidCallback onChanged;
  const _BankGroup({required this.deposits, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bank = deposits.first.bank;
    final activeList = deposits.where((d) => d.status == 'active').toList();
    final closedList = deposits.where((d) => d.status == 'closed').toList();
    final bankTotal = activeList.fold<double>(0, (s, d) => s + d.amount);
    final bankName = bank?.name ?? 'Ngân hàng';
    final bankCode = bank?.code ?? 'BK';
    final hasActive = activeList.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: Theme(
        // Xóa border mặc định của ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: hasActive,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: hasActive ? AppColors.depositLight : Colors.grey[200],
            child: Text(bankCode,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasActive ? AppColors.deposit : Colors.grey)),
          ),
          title: Text(bankName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text(
            '${activeList.length} sổ hiệu lực${closedList.isNotEmpty ? ' · ${closedList.length} đã tất toán' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(bankTotal),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasActive ? AppColors.deposit : Colors.grey),
              ),
              const Icon(Icons.expand_more, size: 18, color: Colors.grey),
            ],
          ),
          children: [
            const Divider(height: 1),
            if (activeList.isNotEmpty) ...[
              _SubHeader('Đang hiệu lực', activeList.length),
              ...activeList.map((d) => _DepositCard(deposit: d, onChanged: onChanged)),
            ],
            if (closedList.isNotEmpty) ...[
              _SubHeader('Đã tất toán', closedList.length),
              ...closedList.map((d) => _DepositCard(deposit: d, onChanged: onChanged)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SubHeader(this.label, this.count);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
}

// ─── Card từng sổ ────────────────────────────────────────────────────────────

class _DepositCard extends StatelessWidget {
  final BankDeposit deposit;
  final VoidCallback onChanged;
  const _DepositCard({required this.deposit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(deposit.dueDate);
    final isActive = deposit.status == 'active';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Đường dọc bên trái
          Container(
            width: 3,
            height: 56,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.deposit.withOpacity(0.4) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatDateFromString(deposit.startDate)} → ${formatDateFromString(deposit.dueDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      formatCurrency(deposit.amount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.deposit : Colors.grey,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (deposit.interestRate != null)
                      Text('${deposit.interestRate}%/năm',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    if (deposit.termMonths != null) ...[
                      Text(' · ', style: TextStyle(color: Colors.grey[400])),
                      Text('${deposit.termMonths} tháng',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                    if (isActive && days <= 7 && days >= 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        days == 0 ? 'Đáo hạn hôm nay!' : 'Còn $days ngày',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            onSelected: (v) async {
              if (v == 'edit') {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddDepositScreen(deposit: deposit)));
                onChanged();
              } else if (v == 'close') {
                final ok = await showConfirmDialog(context,
                    title: 'Tất toán sổ',
                    content: 'Xác nhận tất toán sổ tiết kiệm này?',
                    confirmText: 'Tất toán',
                    confirmColor: Colors.orange);
                if (ok) {
                  await _depRepo.update(deposit.copyWith(status: 'closed'));
                  onChanged();
                }
              } else if (v == 'delete') {
                final ok = await showConfirmDialog(context,
                    title: 'Xóa sổ tiết kiệm',
                    content: 'Bạn chắc chắn muốn xóa?');
                if (ok) {
                  await _depRepo.delete(deposit.id!);
                  onChanged();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Sửa')),
              if (isActive) const PopupMenuItem(value: 'close', child: Text('Tất toán')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }
}
