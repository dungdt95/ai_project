import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import '../../widgets/location_selector.dart';
import '../locations/location_form_screen.dart';
import '../meter/meter_reading_screen.dart';
import 'invoice_create_screen.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late int _month;
  late int _year;
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final list = await app.invoicesOfMonth(_month, _year);
    if (mounted) setState(() => _invoices = list);
  }

  Future<void> _changeMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPicker(initial: DateTime(_year, _month)),
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
    final total = _invoices.fold<int>(0, (s, i) => s + i.total);
    final roomMap = {for (final r in app.rooms) r.id!: r};
    final roomsWithoutInvoice = app.rooms
        .where((r) => !_invoices.any((i) => i.roomId == r.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _changeMonth,
          child: Row(
            children: [
              Text('Hóa đơn ${FormatUtils.monthYear(_month, _year)}'),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                MeterReadingScreen(month: _month, year: _year),
          ));
          await _load();
        },
        icon: const Icon(Icons.electric_meter),
        label: const Text('Ghi số điện/nước'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary.withOpacity(0.06),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng thu tháng',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text('${FormatUtils.money(total)}đ',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_invoices.length}/${app.rooms.length} HĐ',
                        style: const TextStyle(fontSize: 13)),
                    Text(
                        'Còn ${roomsWithoutInvoice.length} phòng chưa nhập',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _invoices.isEmpty && roomsWithoutInvoice.isEmpty
                ? const Center(child: Text('Chưa có dữ liệu'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        if (_invoices.isNotEmpty) ...[
                          const _SectionHeader('Đã có hóa đơn'),
                          ..._invoices.map((inv) {
                            final room = roomMap[inv.roomId];
                            return _invoiceTile(inv, room);
                          }),
                        ],
                        if (roomsWithoutInvoice.isNotEmpty) ...[
                          const _SectionHeader('Chưa nhập hóa đơn'),
                          ...roomsWithoutInvoice.map((r) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.orange.withOpacity(0.15),
                                  child: Text(r.roomNumber,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                title:
                                    Text('Phòng ${r.roomNumber}'),
                                subtitle: Text(app
                                        .currentTenantByRoom[r.id]
                                        ?.fullName ??
                                    'Trống'),
                                trailing: const Icon(Icons.add_circle_outline),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => InvoiceCreateScreen(
                                                month: _month,
                                                year: _year,
                                                roomId: r.id,
                                              )));
                                  await _load();
                                },
                              )),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceTile(Invoice inv, Room? room) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: inv.isPaid
            ? AppColors.statusOccupied.withOpacity(0.15)
            : Colors.orange.withOpacity(0.15),
        child: Icon(
          inv.isPaid ? Icons.check : Icons.pending,
          color: inv.isPaid ? AppColors.statusOccupied : Colors.orange,
        ),
      ),
      title: Text('Phòng ${room?.roomNumber ?? '?'}'),
      subtitle: Text('Điện ${inv.elecUsed}kWh • Nước ${inv.waterUsed}m³'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${FormatUtils.money(inv.total)}đ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(inv.isPaid ? 'Đã thu' : 'Chưa thu',
              style: TextStyle(
                  fontSize: 11,
                  color: inv.isPaid
                      ? AppColors.statusOccupied
                      : Colors.orange)),
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: inv.id!),
        ));
        await _load();
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              fontSize: 12)),
    );
  }
}

class _MonthYearPicker extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPicker({required this.initial});
  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
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
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _year--),
                ),
                Text('Năm $_year',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == _month;
                return ChoiceChip(
                  label: Text('Th $m'),
                  selected: selected,
                  onSelected: (_) => setState(() => _month = m),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}
