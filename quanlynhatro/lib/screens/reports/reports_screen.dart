import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import '../../widgets/location_selector.dart';
import '../locations/location_form_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _month;
  late int _year;

  // Tab tổng hợp
  List<Invoice> _allInvoices = [];
  // Tab theo địa điểm
  List<Invoice> _locationInvoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final all = await app.invoicesOfMonthAll(_month, _year);
    final loc = await app.invoicesOfMonth(_month, _year);
    if (mounted) {
      setState(() {
        _allInvoices = all;
        _locationInvoices = loc;
      });
    }
  }

  Future<void> _changeMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearDialog(initial: DateTime(_year, _month)),
    );
    if (picked != null) {
      setState(() {
        _month = picked.month;
        _year = picked.year;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _changeMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Báo cáo ${FormatUtils.monthYear(_month, _year)}'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          LocationSelector(
            locations: app.locations,
            currentLocationId: app.currentLocationId,
            onChanged: (id) async {
              await context.read<AppState>().switchLocation(id);
              await _load();
            },
            onAddNew: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LocationFormScreen(),
            )),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tổng hợp'),
            Tab(text: 'Theo địa điểm'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(app),
          _buildLocationTab(app),
        ],
      ),
    );
  }

  // ── Tab tổng hợp tất cả địa điểm ──────────────────────────────────────────

  Widget _buildAllTab(AppState app) {
    final invoices = _allInvoices;
    final allRooms = app.rooms; // tất cả phòng đang load (theo location hiện tại, nhưng dùng cho hiển thị)
    final roomMap = {for (final r in allRooms) r.id!: r};

    final total = invoices.fold<int>(0, (s, i) => s + i.total);
    final paidTotal =
        invoices.where((i) => i.isPaid).fold<int>(0, (s, i) => s + i.total);

    int prevM = _month - 1, prevY = _year;
    if (prevM == 0) {
      prevM = 12;
      prevY--;
    }

    return _ReportContent(
      month: _month,
      year: _year,
      invoices: invoices,
      roomMap: roomMap,
      total: total,
      paidTotal: paidTotal,
      subtitle: 'Tất cả địa điểm',
      onRefresh: _load,
      prevMonthLoader: () => app.invoicesOfMonthAll(prevM, prevY),
    );
  }

  // ── Tab theo địa điểm hiện tại ────────────────────────────────────────────

  Widget _buildLocationTab(AppState app) {
    final invoices = _locationInvoices;
    final roomMap = {for (final r in app.rooms) r.id!: r};

    final total = invoices.fold<int>(0, (s, i) => s + i.total);
    final paidTotal =
        invoices.where((i) => i.isPaid).fold<int>(0, (s, i) => s + i.total);

    int prevM = _month - 1, prevY = _year;
    if (prevM == 0) {
      prevM = 12;
      prevY--;
    }

    return _ReportContent(
      month: _month,
      year: _year,
      invoices: invoices,
      roomMap: roomMap,
      total: total,
      paidTotal: paidTotal,
      subtitle: app.currentLocation?.name ?? '—',
      onRefresh: _load,
      prevMonthLoader: () => app.invoicesOfMonth(prevM, prevY),
    );
  }
}

// ── Shared report content widget ──────────────────────────────────────────────

class _ReportContent extends StatefulWidget {
  final int month;
  final int year;
  final List<Invoice> invoices;
  final Map<int, Room> roomMap;
  final int total;
  final int paidTotal;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final Future<List<Invoice>> Function() prevMonthLoader;

  const _ReportContent({
    required this.month,
    required this.year,
    required this.invoices,
    required this.roomMap,
    required this.total,
    required this.paidTotal,
    required this.subtitle,
    required this.onRefresh,
    required this.prevMonthLoader,
  });

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  int _prevTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadPrev();
  }

  @override
  void didUpdateWidget(_ReportContent old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.year != widget.year ||
        old.subtitle != widget.subtitle) {
      _loadPrev();
    }
  }

  Future<void> _loadPrev() async {
    final prev = await widget.prevMonthLoader();
    if (mounted) {
      setState(() => _prevTotal = prev.fold<int>(0, (s, i) => s + i.total));
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.total - _prevTotal;
    final pct = _prevTotal == 0 ? 0.0 : (diff / _prevTotal) * 100;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(widget.total, widget.paidTotal, diff, pct),
          const SizedBox(height: 16),
          _breakdownCard(),
          const SizedBox(height: 16),
          _detailTable(),
        ],
      ),
    );
  }

  Widget _summaryCard(int total, int paid, int diff, double pct) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const Text('Tổng thu tháng',
                style: TextStyle(color: AppColors.textSecondary)),
            Text('${FormatUtils.money(total)}đ',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(diff >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: diff >= 0
                        ? AppColors.statusOccupied
                        : AppColors.statusVacant),
                const SizedBox(width: 4),
                Text(
                    '${diff >= 0 ? '+' : ''}${FormatUtils.money(diff)}đ (${pct.toStringAsFixed(1)}%) so với tháng trước',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: _miniStat('Đã thu', '${FormatUtils.money(paid)}đ',
                        AppColors.statusOccupied)),
                Expanded(
                    child: _miniStat('Chưa thu',
                        '${FormatUtils.money(total - paid)}đ', Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _breakdownCard() {
    final invoices = widget.invoices;
    final items = [
      ('Tiền phòng', invoices.fold<int>(0, (s, i) => s + i.rentFee),
          Colors.blue),
      ('Mạng internet',
          invoices.fold<int>(0, (s, i) => s + i.internetFee), Colors.purple),
      ('Thang máy, VS',
          invoices.fold<int>(0, (s, i) => s + i.elevatorFee), Colors.teal),
      ('Máy giặt',
          invoices.fold<int>(0, (s, i) => s + i.washingFee), Colors.indigo),
      ('Tiền điện', invoices.fold<int>(0, (s, i) => s + i.elecFee),
          Colors.orange),
      ('Tiền nước', invoices.fold<int>(0, (s, i) => s + i.waterFee),
          Colors.cyan),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cơ cấu doanh thu',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: item.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.$1)),
                    Text('${FormatUtils.money(item.$2)}đ'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('Chi tiết theo phòng',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor:
                    MaterialStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('STT')),
                  DataColumn(label: Text('Phòng')),
                  DataColumn(label: Text('Tiền phòng'), numeric: true),
                  DataColumn(label: Text('Điện'), numeric: true),
                  DataColumn(label: Text('Nước'), numeric: true),
                  DataColumn(label: Text('Khác'), numeric: true),
                  DataColumn(label: Text('Tổng'), numeric: true),
                ],
                rows: [
                  for (int i = 0; i < widget.invoices.length; i++)
                    DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(widget.roomMap[widget.invoices[i].roomId]
                              ?.roomNumber ??
                          '?')),
                      DataCell(Text(
                          FormatUtils.money(widget.invoices[i].rentFee))),
                      DataCell(
                          Text(FormatUtils.money(widget.invoices[i].elecFee))),
                      DataCell(Text(
                          FormatUtils.money(widget.invoices[i].waterFee))),
                      DataCell(Text(FormatUtils.money(
                          widget.invoices[i].internetFee +
                              widget.invoices[i].elevatorFee +
                              widget.invoices[i].washingFee))),
                      DataCell(Text(
                          FormatUtils.money(widget.invoices[i].total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold))),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Month/Year picker dialog (reused from invoices screen) ────────────────────

class _MonthYearDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearDialog({required this.initial});
  @override
  State<_MonthYearDialog> createState() => _MonthYearDialogState();
}

class _MonthYearDialogState extends State<_MonthYearDialog> {
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _month = widget.initial.month;
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn tháng'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left)),
                Text('Năm $_year',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  12,
                  (i) => ChoiceChip(
                        label: Text('Th ${i + 1}'),
                        selected: _month == i + 1,
                        onSelected: (_) => setState(() => _month = i + 1),
                      )),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}
