import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/loan.dart';
import '../../../data/models/loan_payment.dart';
import '../../../data/repositories/loan_repository.dart';
import 'add_loan_screen.dart';

final _loanRepo = LoanRepository();

final loanDetailProvider = FutureProvider.family<Loan?, int>((ref, id) async {
  final loans = await _loanRepo.getAll();
  try {
    return loans.firstWhere((l) => l.id == id);
  } catch (_) {
    return null;
  }
});

class LoanDetailScreen extends ConsumerWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(loanDetailProvider(loanId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khoản vay'),
        actions: [
          asyncData.whenOrNull(
            data: (loan) => loan != null
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddLoanScreen(loan: loan)))
                        .then((_) => ref.refresh(loanDetailProvider(loanId))),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (loan) => loan == null
            ? const Center(child: Text('Không tìm thấy'))
            : _LoanDetailBody(loan: loan, onRefresh: () => ref.refresh(loanDetailProvider(loanId))),
      ),
    );
  }
}

class _LoanDetailBody extends StatelessWidget {
  final Loan loan;
  final VoidCallback onRefresh;
  const _LoanDetailBody({required this.loan, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final pctPaid = loan.amount > 0 ? (loan.totalPaid / loan.amount).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.borrower?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _InfoRow('Số tiền cho vay', formatCurrency(loan.amount), AppColors.loan),
                _InfoRow('Đã trả', formatCurrency(loan.totalPaid), AppColors.income),
                _InfoRow('Còn nợ', formatCurrency(loan.remaining),
                    loan.remaining <= 0 ? AppColors.income : AppColors.expense),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: pctPaid as double, color: AppColors.income, backgroundColor: Colors.grey[200]),
                const SizedBox(height: 4),
                Text('${(pctPaid * 100).toStringAsFixed(0)}% đã trả', style: const TextStyle(fontSize: 12)),
                const Divider(height: 20),
                _InfoRow('Ngày cho vay', formatDateFromString(loan.loanDate), Colors.grey[700]!),
                _InfoRow('Ngày dự kiến trả', formatDateFromString(loan.expectedReturnDate), Colors.grey[700]!),
                if (loan.interestRate > 0)
                  _InfoRow('Lãi suất', '${loan.interestRate}%/năm', Colors.grey[700]!),
                if (loan.note != null) _InfoRow('Ghi chú', loan.note!, Colors.grey[700]!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Lịch sử trả nợ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (loan.status != 'paid')
              ElevatedButton.icon(
                onPressed: () => _showAddPaymentDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ghi nhận trả'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loan.payments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Chưa có lần trả nào')))
        else
          ...loan.payments.map((p) => _PaymentTile(payment: p, loan: loan, onDeleted: onRefresh)),
      ],
    );
  }

  Future<void> _showAddPaymentDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime paidDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Ghi nhận trả nợ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                decoration: const InputDecoration(labelText: 'Số tiền *', suffixText: 'đ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(context: ctx, initialDate: paidDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (p != null) setStateDialog(() => paidDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày trả', border: OutlineInputBorder()),
                  child: Text(formatDate(paidDate)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final amount = parseAmount(amountCtrl.text);
                if (amount <= 0) return;
                await LoanRepository().insertPayment(LoanPayment(
                  loanId: loan.id!,
                  amount: amount,
                  paidDate: toIso(paidDate),
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                onRefresh();
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}

class _PaymentTile extends StatelessWidget {
  final LoanPayment payment;
  final Loan loan;
  final VoidCallback onDeleted;
  const _PaymentTile({required this.payment, required this.loan, required this.onDeleted});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.incomeLight,
          child: Icon(Icons.check, color: AppColors.income, size: 18),
        ),
        title: Text(formatCurrency(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
        subtitle: Text(formatDateFromString(payment.paidDate)),
        trailing: payment.note != null ? Text(payment.note!, style: const TextStyle(fontSize: 12)) : null,
      );
}
