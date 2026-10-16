import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../../data/models/loan.dart';
import 'loan_detail_screen.dart';
import 'add_loan_screen.dart';

final _loanRepo = LoanRepository();

final borrowerLoansProvider = FutureProvider.family<List<Loan>, int>(
  (ref, borrowerId) => _loanRepo.getAll(borrowerId: borrowerId),
);

class BorrowerLoansScreen extends ConsumerWidget {
  final int borrowerId;
  final String borrowerName;
  const BorrowerLoansScreen({super.key, required this.borrowerId, required this.borrowerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(borrowerLoansProvider(borrowerId));
    return Scaffold(
      appBar: AppBar(title: Text(borrowerName)),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (loans) {
          if (loans.isEmpty) {
            return const Center(child: Text('Chưa có khoản vay'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: loans.length,
            itemBuilder: (_, i) => _LoanCard(
              loan: loans[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LoanDetailScreen(loanId: loans[i].id!),
              )).then((_) => ref.refresh(borrowerLoansProvider(borrowerId))),
              onDelete: () async {
                final ok = await showConfirmDialog(context,
                    title: 'Xóa khoản vay', content: 'Bạn chắc chắn muốn xóa khoản vay này?');
                if (ok) {
                  await _loanRepo.delete(loans[i].id!);
                  // ignore: unused_result
                  ref.refresh(borrowerLoansProvider(borrowerId));
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_borrower_loans',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddLoanScreen(preselectedBorrowerId: borrowerId),
        )).then((_) => ref.refresh(borrowerLoansProvider(borrowerId))),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _LoanCard({required this.loan, required this.onTap, required this.onDelete});

  Color get _statusColor {
    switch (loan.status) {
      case 'paid': return AppColors.income;
      case 'overdue': return AppColors.expense;
      case 'partial': return Colors.orange;
      default: return AppColors.loan;
    }
  }

  String get _statusLabel {
    switch (loan.status) {
      case 'paid': return 'Đã trả đủ';
      case 'overdue': return 'Quá hạn';
      case 'partial': return 'Trả một phần';
      default: return 'Chưa trả';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cho vay ${formatDateFromString(loan.loanDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_statusLabel, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Số tiền', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Text(formatCurrency(loan.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.loan)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Còn nợ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Text(formatCurrency(loan.remaining), style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: loan.status == 'paid' ? AppColors.income : AppColors.expense)),
                  ]),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hạn trả: ${formatDateFromString(loan.expectedReturnDate)}',
                      style: const TextStyle(fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
