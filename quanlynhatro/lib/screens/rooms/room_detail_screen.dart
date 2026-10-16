import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import '../invoices/invoice_create_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../tenants/tenant_form_screen.dart';
import 'room_form_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  Room? _room;
  Tenant? _tenant;
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final fresh = await app.roomRepo.getById(widget.room.id!);
    final t = await app.tenantRepo.getCurrentByRoom(widget.room.id!);
    final inv = await app.invoiceRepo.getByRoom(widget.room.id!);
    if (mounted) {
      setState(() {
        _room = fresh ?? widget.room;
        _tenant = t;
        _invoices = inv;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room ?? widget.room;
    return Scaffold(
      appBar: AppBar(
        title: Text('Phòng ${room.roomNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => RoomFormScreen(room: room)),
              );
              if (updated == true) await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final now = DateTime.now();
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => InvoiceCreateScreen(
              month: now.month,
              year: now.year,
              roomId: room.id,
            ),
          ));
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo hóa đơn'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRoomInfo(room),
          const SizedBox(height: 16),
          _buildTenantSection(room),
          const SizedBox(height: 16),
          _buildInvoiceList(),
        ],
      ),
    );
  }

  Widget _buildRoomInfo(Room room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin phòng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _row('Tầng', room.floor?.toString() ?? '-'),
            _row('Tiền phòng', '${FormatUtils.money(room.baseRent)}đ'),
            _row('Mạng internet', '${FormatUtils.money(room.internetFee)}đ'),
            _row('Thang máy, vệ sinh',
                '${FormatUtils.money(room.elevatorFee)}đ'),
            _row('Máy giặt', '${FormatUtils.money(room.washingFee)}đ'),
            _row('Trạng thái',
                room.isOccupied ? 'Đang thuê' : 'Trống'),
            if (room.notes != null) _row('Ghi chú', room.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantSection(Room room) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Khách thuê hiện tại',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: Icon(_tenant == null ? Icons.add : Icons.edit),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TenantFormScreen(
                          roomId: room.id!, tenant: _tenant),
                    ));
                    await _load();
                  },
                ),
              ],
            ),
            const Divider(),
            if (_tenant == null)
              const Text('Phòng chưa có khách thuê.',
                  style: TextStyle(color: AppColors.textSecondary))
            else ...[
              _row('Tên', _tenant!.fullName),
              _row('SĐT', _tenant!.phone ?? '-',
                  trailing: _tenant!.phone != null
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, size: 20),
                              onPressed: () =>
                                  launchUrl(Uri.parse('tel:${_tenant!.phone}')),
                            ),
                            IconButton(
                              icon: const Icon(Icons.message, size: 20),
                              onPressed: () => launchUrl(
                                  Uri.parse('sms:${_tenant!.phone}')),
                            ),
                          ],
                        )
                      : null),
              _row('Ngày ký HĐ', FormatUtils.date(_tenant!.contractStart)),
              _row('Ngày hết HĐ', FormatUtils.date(_tenant!.contractEnd)),
              if (_tenant!.deposit > 0)
                _row('Tiền cọc', '${FormatUtils.money(_tenant!.deposit)}đ'),
              if (_tenant!.daysToExpire() != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tenant!.isExpired
                        ? Colors.red.withOpacity(0.1)
                        : (_tenant!.isExpiring
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _tenant!.isExpired
                        ? 'Đã quá hạn ${-_tenant!.daysToExpire()!} ngày'
                        : 'Còn ${_tenant!.daysToExpire()} ngày',
                    style: TextStyle(
                      color: _tenant!.isExpired
                          ? Colors.red
                          : (_tenant!.isExpiring
                              ? Colors.orange.shade800
                              : Colors.green),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lịch sử hóa đơn',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (_invoices.isEmpty)
              const Text('Chưa có hóa đơn nào.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ..._invoices.map((inv) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: inv.isPaid
                          ? AppColors.statusOccupied.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      child: Icon(
                        inv.isPaid ? Icons.check : Icons.pending,
                        color: inv.isPaid
                            ? AppColors.statusOccupied
                            : Colors.orange,
                      ),
                    ),
                    title:
                        Text(FormatUtils.monthName(inv.month, inv.year)),
                    subtitle: Text(
                        'Điện ${inv.elecUsed}kWh • Nước ${inv.waterUsed}m³'),
                    trailing: Text('${FormatUtils.money(inv.total)}đ',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => InvoiceDetailScreen(invoiceId: inv.id!),
                      ));
                      await _load();
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
