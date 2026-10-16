import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/repositories/loan_repository.dart';
import 'add_loan_screen.dart';
import 'borrower_loans_screen.dart';

final _loanRepo = LoanRepository();

final borrowerSummaryProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _loanRepo.getBorrowerSummary(),
);

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(borrowerSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cho vay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Quản lý người vay',
            onPressed: () => Navigator.pushNamed(context, '/borrowers')
                .then((_) => ref.refresh(borrowerSummaryProvider)),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (summaries) {
          if (summaries.isEmpty) {
            return const EmptyState(
              message: 'Chưa có khoản vay nào',
              icon: Icons.handshake_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(borrowerSummaryProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: summaries.length,
              itemBuilder: (_, i) => _BorrowerCard(
                summary: summaries[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BorrowerLoansScreen(
                      borrowerId: summaries[i]['id'] as int,
                      borrowerName: summaries[i]['name'] as String,
                    ),
                  ),
                ).then((_) => ref.refresh(borrowerSummaryProvider)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_loans',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddLoanScreen()),
        ).then((_) => ref.refresh(borrowerSummaryProvider)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BorrowerCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final VoidCallback onTap;
  const _BorrowerCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outstanding = (summary['outstanding'] as num? ?? 0).toDouble();
    final totalLent = (summary['total_lent'] as num? ?? 0).toDouble();
    final totalPaid = (summary['total_paid'] as num? ?? 0).toDouble();
    final openLoans = summary['open_loans'] as int? ?? 0;
    final name = summary['name'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.loanLight,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.loan, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (summary['phone'] != null)
                          Text(summary['phone'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Còn nợ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      Text(formatCurrency(outstanding),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.loan, fontSize: 15)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip('Đã cho vay', formatCurrency(totalLent), Colors.orange),
                  _InfoChip('Đã thu hồi', formatCurrency(totalPaid), AppColors.income),
                  _InfoChip('Khoản mở', '$openLoans khoản', AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}
