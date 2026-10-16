import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/payment_method.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'add_transaction_screen.dart';

final _txRepo = TransactionRepository();
final _catRepo = CategoryRepository();

final transactionsProvider = FutureProvider.family<List<Transaction>, Map<String, dynamic>>((ref, params) async {
  return _txRepo.getAll(
    type: params['type'] as String?,
    startDate: params['startDate'] as String?,
    endDate: params['endDate'] as String?,
  );
});

final categoriesByTypeProvider = FutureProvider.family<List<Category>, String>(
  (ref, type) => _catRepo.getAll(type: type),
);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _params => {
        'startDate':
            '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01',
        'endDate':
            toIso(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0)),
      };

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chi tiêu'), Tab(text: 'Thu nhập')],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickMonth),
        ],
      ),
      body: Column(
        children: [
          _MonthHeader(month: _selectedMonth, params: _params),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TxList(
                  params: {..._params, 'type': 'expense'},
                  type: 'expense',
                  isExpense: true,
                  onRefresh: _refresh,
                ),
                _TxList(
                  params: {..._params, 'type': 'income'},
                  type: 'income',
                  isExpense: false,
                  onRefresh: _refresh,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_transactions',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ).then((_) => _refresh()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn tháng',
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }
}

// ─── Month header ────────────────────────────────────────────────────────────

class _MonthHeader extends ConsumerWidget {
  final DateTime month;
  final Map<String, dynamic> params;
  const _MonthHeader({required this.month, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(transactionsProvider(params));
    return asyncData.when(
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox(height: 44),
      data: (txs) {
        double income = 0, expense = 0;
        for (final t in txs) {
          if (t.type == 'income') income += t.amount;
          else expense += t.amount;
        }
        return Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tháng ${month.month}/${month.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [
                Text(formatCurrency(income),
                    style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text(formatCurrency(expense),
                    style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ─── Transaction list (with category grid on top) ───────────────────────────

class _TxList extends ConsumerWidget {
  final Map<String, dynamic> params;
  final String type;
  final bool isExpense;
  final VoidCallback onRefresh;
  const _TxList({
    required this.params,
    required this.type,
    required this.isExpense,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(transactionsProvider(params));
    final asyncCats = ref.watch(categoriesByTypeProvider(type));

    final color = isExpense ? AppColors.expense : AppColors.income;
    final bgColor = isExpense ? AppColors.expenseLight : AppColors.incomeLight;

    return asyncTx.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txs) {
        final grouped = <String, List<Transaction>>{};
        for (final t in txs) grouped.putIfAbsent(t.date, () => []).add(t);

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: CustomScrollView(
            slivers: [
              // ── Category icon grid ──
              SliverToBoxAdapter(
                child: asyncCats.when(
                  loading: () => const SizedBox(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cats) => _CategoryGrid(
                    categories: cats,
                    type: type,
                    isExpense: isExpense,
                    color: color,
                    bgColor: bgColor,
                    onRefresh: onRefresh,
                    onCategoryAdded: () {
                      ref.invalidate(categoriesByTypeProvider(type));
                      onRefresh();
                    },
                  ),
                ),
              ),
              // ── Transaction list ──
              if (txs.isEmpty)
                SliverFillRemaining(
                  child: EmptyState(
                    message: 'Chưa có ${isExpense ? 'chi tiêu' : 'thu nhập'}',
                    icon: isExpense
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final date = grouped.keys.elementAt(i);
                      final dayTxs = grouped[date]!;
                      final dayTotal =
                          dayTxs.fold<double>(0, (s, t) => s + t.amount);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatDateFromString(date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(formatCurrency(dayTotal),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          ...dayTxs.map((t) => _TxTile(
                                tx: t,
                                isExpense: isExpense,
                                onRefresh: onRefresh,
                                onDelete: () async {
                                  await _txRepo.delete(t.id!);
                                  onRefresh();
                                },
                              )),
                        ],
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              // Padding cuối để FAB không che row cuối
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Category icon grid ───────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final String type;
  final bool isExpense;
  final Color color;
  final Color bgColor;
  final VoidCallback onRefresh;
  final VoidCallback onCategoryAdded;

  const _CategoryGrid({
    required this.categories,
    required this.type,
    required this.isExpense,
    required this.color,
    required this.bgColor,
    required this.onRefresh,
    required this.onCategoryAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ...categories.map((cat) => _CategoryChip(
                  category: cat,
                  color: color,
                  bgColor: bgColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(
                        initialType: type,
                        initialCategoryId: cat.id,
                      ),
                    ),
                  ).then((_) => onRefresh()),
                )),
            // Nút thêm danh mục mới
            _AddCategoryChip(
              type: type,
              color: color,
              onAdded: onCategoryAdded,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: bgColor,
              child: Icon(iconFromString(category.icon), color: color, size: 22),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  final String type;
  final Color color;
  final VoidCallback onAdded;

  const _AddCategoryChip({
    required this.type,
    required this.color,
    required this.onAdded,
  });

  static const _iconOptions = [
    'restaurant', 'directions_car', 'shopping_bag', 'receipt', 'movie',
    'local_hospital', 'school', 'home', 'phone', 'wifi', 'sports', 'pets',
    'flight', 'hotel', 'coffee', 'fitness_center', 'book', 'music_note',
    'games', 'child_care', 'work', 'savings', 'attach_money',
    'payments', 'card_giftcard', 'trending_up', 'redeem', 'more_horiz',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddDialog(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.add, color: Colors.grey[600], size: 22),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              'Thêm mới',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    String selectedIcon = type == 'expense' ? 'more_horiz' : 'payments';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Thêm danh mục ${type == 'expense' ? 'chi tiêu' : 'thu nhập'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Chọn icon:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconOptions.map((iconName) {
                    final isSelected = iconName == selectedIcon;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedIcon = iconName),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected
                            ? color.withOpacity(0.2)
                            : Colors.grey[100],
                        child: Icon(
                          iconFromString(iconName),
                          size: 18,
                          color: isSelected ? color : Colors.grey[600],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await _catRepo.insert(Category(
                  name: name,
                  type: type,
                  icon: selectedIcon,
                  color: '#9E9E9E',
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                onAdded();
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final Transaction tx;
  final bool isExpense;
  final VoidCallback onRefresh;
  final Future<void> Function() onDelete;
  const _TxTile(
      {required this.tx, required this.isExpense, required this.onRefresh, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense ? AppColors.expenseLight : AppColors.incomeLight,
        child: Icon(
          iconFromString(tx.category?.icon),
          size: 18,
          color: isExpense ? AppColors.expense : AppColors.income,
        ),
      ),
      title: Text(tx.category?.name ?? '', style: const TextStyle(fontSize: 14)),
      subtitle: (tx.paymentMethod == null && tx.note == null)
          ? null
          : Row(
        children: [
          if (tx.paymentMethod != null) ...[
            Icon(PaymentMethods.icon(tx.paymentMethod), size: 13, color: Colors.grey[600]),
            const SizedBox(width: 3),
            Text(PaymentMethods.label(tx.paymentMethod),
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
          if (tx.paymentMethod != null && tx.note != null)
            Text(' · ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (tx.note != null)
            Expanded(
              child: Text(tx.note!,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(amount: tx.amount, isExpense: isExpense),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(transaction: tx)),
                );
                onRefresh();
              } else if (v == 'delete') {
                final ok = await showConfirmDialog(context,
                    title: 'Xóa giao dịch',
                    content: 'Bạn chắc chắn muốn xóa giao dịch này?');
                if (ok) await onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Sửa')),
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
