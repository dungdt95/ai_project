import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/deposit_repository.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/models/bank_deposit.dart';
import '../../../data/models/loan.dart';

final _txRepo = TransactionRepository();
final _depRepo = DepositRepository();
final _loanRepo = LoanRepository();
final _settingsRepo = SettingsRepository();

// Tăng counter này để force refresh Home
final homeRefreshProvider = StateProvider<int>((ref) => 0);

final homeSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(homeRefreshProvider); // re-fetch khi counter thay đổi
  final now = DateTime.now();
  final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  final end = toIso(now);

  final prevMonth = DateTime(now.year, now.month - 1);
  final prevStart = '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}-01';
  final prevEnd = DateTime(now.year, now.month, 0);
  final prevEndStr = toIso(prevEnd);

  final [current, prev, deposits, loans, upcoming, upcomingLoans, _] = await Future.wait([
    _txRepo.getSummary(start, end),
    _txRepo.getSummary(prevStart, prevEndStr),
    _depRepo.getTotalActive(),
    _loanRepo.getTotalOutstanding(),
    _depRepo.getUpcoming(7),
    _loanRepo.getAll(),
    _settingsRepo.getReminderDays(),
  ]);

  final recentTx = await _txRepo.getAll(startDate: start, endDate: end);
  final recent5 = recentTx.take(5).toList();

  final upcomingLoanList = (upcomingLoans as List<Loan>)
      .where((l) => l.status != 'paid' && daysUntil(l.expectedReturnDate) <= 7 && daysUntil(l.expectedReturnDate) >= 0)
      .toList();

  return {
    'current': current as Map<String, double>,
    'prev': prev as Map<String, double>,
    'depositTotal': deposits as double,
    'loanOutstanding': loans as double,
    'recentTx': recent5,
    'upcomingDeposits': upcoming as List<BankDeposit>,
    'upcomingLoans': upcomingLoanList,
  };
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings')
                .then((_) => ref.refresh(homeSummaryProvider)),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) => _buildBody(context, ref, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final current = data['current'] as Map<String, double>;
    final prev = data['prev'] as Map<String, double>;
    final income = current['income'] ?? 0;
    final credit = current['credit'] ?? 0;
    // Chi tiêu thực (tiền mặt/TK) = tổng chi tiêu trừ phần tín dụng
    final expense = (current['expense'] ?? 0) - credit;
    final balance = income - expense; // số dư không bị ảnh hưởng bởi tín dụng
    final prevCredit = prev['credit'] ?? 0;
    final prevBalance = (prev['income'] ?? 0) - ((prev['expense'] ?? 0) - prevCredit);
    final depositTotal = data['depositTotal'] as double;
    final loanOutstanding = data['loanOutstanding'] as double;
    // Tín dụng là khoản nợ phải trả → trừ khỏi tổng tài sản
    final totalAsset = balance + depositTotal + loanOutstanding - credit;
    final upcomingDeposits = data['upcomingDeposits'] as List<BankDeposit>;
    final upcomingLoans = data['upcomingLoans'] as List<Loan>;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(homeSummaryProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(income: income, expense: expense, balance: balance, credit: credit, prevBalance: prevBalance),
          const SizedBox(height: 12),
          _AssetCard(balance: balance, depositTotal: depositTotal, loanOutstanding: loanOutstanding, credit: credit, totalAsset: totalAsset),
          if (upcomingDeposits.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionTitle('Sổ sắp đáo hạn', Icons.warning_amber, Colors.orange),
            ...upcomingDeposits.map((d) => _DepositAlertTile(d)),
          ],
          if (upcomingLoans.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionTitle('Khoản vay sắp đến hạn', Icons.access_time, Colors.red),
            ...upcomingLoans.map((l) => _LoanAlertTile(l)),
          ],
          const SizedBox(height: 12),
          _SectionTitle('Giao dịch gần đây', Icons.history, Colors.grey),
          ...(data['recentTx'] as List).isEmpty
              ? [const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Chưa có giao dịch')))]
              : (data['recentTx'] as List).map((t) => _RecentTxTile(t)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double income, expense, balance, credit, prevBalance;
  const _SummaryCard({required this.income, required this.expense, required this.balance, required this.credit, required this.prevBalance});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tháng ${now.month}/${now.year}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem('Thu nhập', income, AppColors.income),
                _StatItem('Chi tiêu', expense, AppColors.expense),
                _StatItem('Số dư', balance, balance >= 0 ? AppColors.income : AppColors.expense),
              ],
            ),
            if (credit > 0) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16, color: AppColors.loan),
                      const SizedBox(width: 6),
                      Text('Chi tiêu tín dụng', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                  Text(formatCurrency(credit),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.loan)),
                ],
              ),
              const SizedBox(height: 2),
              Text('(không tính vào chi tiêu & số dư)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
            if (prevBalance != 0) ...[
              const SizedBox(height: 8),
              Text(
                'So tháng trước: ${percentChange(balance, prevBalance)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _StatItem(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(formatCurrency(amount.abs()), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      );
}

class _AssetCard extends StatelessWidget {
  final double balance, depositTotal, loanOutstanding, credit, totalAsset;
  const _AssetCard({required this.balance, required this.depositTotal, required this.loanOutstanding, required this.credit, required this.totalAsset});

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng tài sản', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(formatCurrency(totalAsset), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Divider(height: 20),
              _AssetRow('Tiền mặt/TK', balance, AppColors.income),
              _AssetRow('Tiền gửi ngân hàng', depositTotal, AppColors.deposit),
              _AssetRow('Đang cho vay', loanOutstanding, AppColors.loan),
              if (credit > 0) _AssetRow('Dư nợ tín dụng', -credit, AppColors.expense),
            ],
          ),
        ),
      );
}

class _AssetRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AssetRow(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(formatCurrency(amount), style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}

class _DepositAlertTile extends StatelessWidget {
  final BankDeposit deposit;
  const _DepositAlertTile(this.deposit);

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(deposit.dueDate);
    return Card(
      color: AppColors.depositLight,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.account_balance, color: AppColors.deposit),
        title: Text(deposit.bank?.name ?? 'Ngân hàng'),
        subtitle: Text('Đáo hạn: ${formatDateFromString(deposit.dueDate)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatCurrency(deposit.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(days == 0 ? 'Hôm nay' : 'Còn $days ngày', style: const TextStyle(color: Colors.orange, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _LoanAlertTile extends StatelessWidget {
  final Loan loan;
  const _LoanAlertTile(this.loan);

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(loan.expectedReturnDate);
    return Card(
      color: AppColors.loanLight,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.person_outline, color: AppColors.loan),
        title: Text(loan.borrower?.name ?? ''),
        subtitle: Text('Dự kiến trả: ${formatDateFromString(loan.expectedReturnDate)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatCurrency(loan.remaining), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.loan)),
            Text(days == 0 ? 'Hôm nay' : 'Còn $days ngày', style: const TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final dynamic tx;
  const _RecentTxTile(this.tx);

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.type == 'expense';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: isExpense ? AppColors.expenseLight : AppColors.incomeLight,
        child: Icon(Icons.category, size: 18, color: isExpense ? AppColors.expense : AppColors.income),
      ),
      title: Text(tx.category?.name ?? '', style: const TextStyle(fontSize: 14)),
      subtitle: Text(formatDateFromString(tx.date), style: const TextStyle(fontSize: 12)),
      trailing: AmountText(amount: tx.amount, isExpense: isExpense),
    );
  }
}
