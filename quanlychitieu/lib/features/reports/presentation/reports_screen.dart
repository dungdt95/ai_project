import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/deposit_repository.dart';
import '../../../data/repositories/loan_repository.dart';

final _txRepo = TransactionRepository();
final _depRepo = DepositRepository();
final _loanRepo = LoanRepository();

// Tăng counter này để force refresh Reports
final reportsRefreshProvider = StateProvider<int>((ref) => 0);

// Provider riêng cho pie chart — tham số: "start|end"
final pieCategoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, periodKey) async {
    ref.watch(reportsRefreshProvider);
    final parts = periodKey.split('|');
    return _txRepo.getCategoryTotals('expense', parts[0], parts[1]);
  },
);

/// Tính Thứ 2 đầu tuần của ngày bất kỳ
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day)
    .subtract(Duration(days: d.weekday - 1));

/// Period key Tuần (Thứ 2 → Chủ nhật) cho ngày bất kỳ
String weekPeriodKeyOf(DateTime d) {
  final monday = mondayOf(d);
  final sunday = monday.add(const Duration(days: 6));
  return '${toIso(monday)}|${toIso(sunday)}';
}

/// Period key Tháng cho 1 tháng bất kỳ
String monthPeriodKeyOf(DateTime d) {
  final start = DateTime(d.year, d.month, 1);
  final end = DateTime(d.year, d.month + 1, 0);
  return '${toIso(start)}|${toIso(end)}';
}

/// Label hiển thị cho tuần
String weekLabel(DateTime d) {
  final monday = mondayOf(d);
  final sunday = monday.add(const Duration(days: 6));
  return '${formatDate(monday)} → ${formatDate(sunday)}';
}

// Dùng String "start|end" thay Map để Riverpod so sánh được bằng ==
final reportsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, periodKey) async {
  ref.watch(reportsRefreshProvider); // re-fetch khi counter thay đổi
  final parts = periodKey.split('|');
  final start = parts[0];
  final end = parts[1];

  final results = await Future.wait([
    _txRepo.getSummary(start, end),
    _txRepo.getCategoryTotals('expense', start, end),
    _txRepo.getMonthlyTotals(12),
    _depRepo.getTotalActive(),
    _loanRepo.getTotalOutstanding(),
    _loanRepo.getBorrowerSummary(),
    _txRepo.getSummary('2000-01-01', end), // all-time cho tổng tài sản
  ]);

  final allSummary = results[6] as Map<String, double>;
  final cashBalance = (allSummary['income'] ?? 0) - (allSummary['expense'] ?? 0);

  return {
    'summary': results[0],
    'categoryTotals': results[1],
    'monthly': results[2],
    'depositTotal': results[3],
    'loanOutstanding': results[4],
    'cashBalance': cashBalance,
    'borrowerSummary': results[5],
  };
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _periodLabel = 'Tháng này';
  late DateTime _start, _end;

  @override
  void initState() {
    super.initState();
    _setMonth(DateTime.now());
  }

  void _setMonth(DateTime m) {
    _start = DateTime(m.year, m.month, 1);
    _end = DateTime(m.year, m.month + 1, 0);
    _periodLabel = 'T${m.month}/${m.year}';
  }

  String get _periodKey => '${toIso(_start)}|${toIso(_end)}';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(reportsProvider(_periodKey));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        actions: [
          TextButton(
            onPressed: _pickPeriod,
            child: Text(_periodLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(reportsProvider(_periodKey)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCards(data: data),
              const SizedBox(height: 16),
              _TotalAssetCard(data: data),
              const SizedBox(height: 16),
              _PieChartCard(monthPeriodKey: _periodKey, monthLabel: _periodLabel),
              const SizedBox(height: 16),
              _BarChartCard(monthly: data['monthly'] as List),
              const SizedBox(height: 16),
              _BorrowerRankCard(borrowers: data['borrowerSummary'] as List),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn tháng để xem báo cáo',
    );
    if (picked != null) setState(() => _setMonth(picked));
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, double>;
    final income = summary['income'] ?? 0;
    final expense = summary['expense'] ?? 0;
    final balance = income - expense;
    return Row(
      children: [
        Expanded(child: _StatCard('Thu nhập', income, AppColors.income, Icons.arrow_upward)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard('Chi tiêu', expense, AppColors.expense, Icons.arrow_downward)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard('Số dư', balance, balance >= 0 ? AppColors.income : AppColors.expense, Icons.account_balance_wallet)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(formatCurrency(amount.abs()), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _TotalAssetCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TotalAssetCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cashBalance = data['cashBalance'] as double;
    final depositTotal = data['depositTotal'] as double;
    final loanOutstanding = data['loanOutstanding'] as double;
    final totalAsset = cashBalance + depositTotal + loanOutstanding;
    return Card(
      color: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng tài sản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(formatCurrency(totalAsset),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(height: 16),
            _AssetRow('Tiền mặt/TK', cashBalance, AppColors.income),
            _AssetRow('Tiền gửi NH', depositTotal, AppColors.deposit),
            _AssetRow('Đang cho vay', loanOutstanding, AppColors.loan),
          ],
        ),
      ),
    );
  }
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
            Text(label),
            Text(formatCurrency(amount), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _PieChartCard extends ConsumerStatefulWidget {
  final String monthPeriodKey;
  final String monthLabel;
  const _PieChartCard({required this.monthPeriodKey, required this.monthLabel});

  @override
  ConsumerState<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends ConsumerState<_PieChartCard> {
  bool _isWeek = false;
  int _touchedIndex = -1;
  // State riêng cho từng mode
  late DateTime _selectedMonth;
  late DateTime _selectedWeekDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _selectedWeekDate = DateTime.now();
  }

  String get _activePeriodKey => _isWeek
      ? weekPeriodKeyOf(_selectedWeekDate)
      : monthPeriodKeyOf(_selectedMonth);

  String get _activeLabel => _isWeek
      ? weekLabel(_selectedWeekDate)
      : 'Tháng ${_selectedMonth.month}/${_selectedMonth.year}';

  Future<void> _pickPeriod() async {
    if (_isWeek) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedWeekDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        helpText: 'Chọn 1 ngày trong tuần',
      );
      if (picked != null) {
        setState(() {
          _selectedWeekDate = picked;
          _touchedIndex = -1;
        });
      }
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedMonth,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: 'Chọn tháng',
      );
      if (picked != null) {
        setState(() {
          _selectedMonth = picked;
          _touchedIndex = -1;
        });
      }
    }
  }

  void _shiftPeriod(int delta) {
    setState(() {
      if (_isWeek) {
        _selectedWeekDate = _selectedWeekDate.add(Duration(days: 7 * delta));
      } else {
        _selectedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month + delta,
          1,
        );
      }
      _touchedIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(pieCategoryProvider(_activePeriodKey));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chi tiêu theo danh mục', style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Tháng')),
                    ButtonSegment(value: true, label: Text('Tuần')),
                  ],
                  selected: {_isWeek},
                  onSelectionChanged: (s) => setState(() {
                    _isWeek = s.first;
                    _touchedIndex = -1;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Selector: prev | label (tap để chọn) | next
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => _shiftPeriod(-1),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickPeriod,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isWeek ? Icons.date_range : Icons.calendar_month,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _activeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () => _shiftPeriod(1),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            asyncData.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi: $e'),
              data: (categoryTotals) {
                if (categoryTotals.isEmpty) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: Text('Không có dữ liệu chi tiêu', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                final total = categoryTotals.fold<double>(0, (s, c) => s + (c['total'] as num).toDouble());
                final sections = categoryTotals.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value as Map<String, dynamic>;
                  final value = (c['total'] as num).toDouble();
                  final pct = value / total * 100;
                  final isTouched = i == _touchedIndex;
                  return PieChartSectionData(
                    value: value,
                    title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                    radius: isTouched ? 60 : 50,
                    color: AppColors.categoryColors[i % AppColors.categoryColors.length],
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList();

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(PieChartData(
                        sections: sections,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) => setState(() {
                            _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                          }),
                        ),
                        centerSpaceRadius: 40,
                      )),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: categoryTotals.asMap().entries.map((entry) {
                        final i = entry.key;
                        final c = entry.value as Map<String, dynamic>;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.categoryColors[i % AppColors.categoryColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${c['name']} (${formatCurrency((c['total'] as num).toDouble())})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final List monthly;
  const _BarChartCard({required this.monthly});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) return const SizedBox.shrink();

    final groups = monthly.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value as Map<String, dynamic>;
      final income = (m['income'] as num? ?? 0).toDouble();
      final expense = (m['expense'] as num? ?? 0).toDouble();
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: income, color: AppColors.income, width: 8, borderRadius: BorderRadius.circular(2)),
        BarChartRodData(toY: expense, color: AppColors.expense, width: 8, borderRadius: BorderRadius.circular(2)),
      ]);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thu/Chi theo tháng (12 tháng)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              _Legend('Thu nhập', AppColors.income),
              const SizedBox(width: 12),
              _Legend('Chi tiêu', AppColors.expense),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                barGroups: groups,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i < 0 || i >= monthly.length) return const Text('');
                      final month = (monthly[i] as Map)['month'] as String? ?? '';
                      final parts = month.split('-');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(parts.length >= 2 ? 'T${parts[1]}' : '', style: const TextStyle(fontSize: 9)),
                      );
                    },
                  )),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _BorrowerRankCard extends StatelessWidget {
  final List borrowers;
  const _BorrowerRankCard({required this.borrowers});

  @override
  Widget build(BuildContext context) {
    if (borrowers.isEmpty) return const SizedBox.shrink();
    final sorted = borrowers.where((b) => (b['outstanding'] as num? ?? 0) > 0).toList();
    if (sorted.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Người vay đang nợ nhiều nhất', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...sorted.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final b = entry.value as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: AppColors.loanLight,
                    child: Text('$i', style: const TextStyle(color: AppColors.loan, fontSize: 12, fontWeight: FontWeight.bold))),
                title: Text(b['name'] as String? ?? ''),
                trailing: Text(formatCurrency((b['outstanding'] as num? ?? 0).toDouble()),
                    style: const TextStyle(color: AppColors.loan, fontWeight: FontWeight.bold)),
              );
            }),
          ],
        ),
      ),
    );
  }
}
