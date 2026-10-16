import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import 'invoice_detail_screen.dart';

class InvoiceCreateScreen extends StatefulWidget {
  final int month;
  final int year;
  final int? roomId;

  const InvoiceCreateScreen({
    super.key,
    required this.month,
    required this.year,
    this.roomId,
  });

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  Room? _selectedRoom;
  Tenant? _tenant;
  Invoice? _existing;
  Invoice? _previousInvoice;
  int _elecPrice = AppConstants.defaultElecPrice;
  int _waterPrice = AppConstants.defaultWaterPrice;

  late TextEditingController _rent;
  late TextEditingController _internet;
  late TextEditingController _elevator;
  late TextEditingController _washing;
  late TextEditingController _elecOld;
  late TextEditingController _elecNew;
  late TextEditingController _waterOld;
  late TextEditingController _waterNew;

  @override
  void initState() {
    super.initState();
    _rent = TextEditingController();
    _internet = TextEditingController();
    _elevator = TextEditingController();
    _washing = TextEditingController();
    _elecOld = TextEditingController();
    _elecNew = TextEditingController();
    _waterOld = TextEditingController();
    _waterNew = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _rent.dispose();
    _internet.dispose();
    _elevator.dispose();
    _washing.dispose();
    _elecOld.dispose();
    _elecNew.dispose();
    _waterOld.dispose();
    _waterNew.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final app = context.read<AppState>();
    // Ưu tiên giá từ location của phòng, fallback về settings cũ
    if (widget.roomId != null) {
      final room = await app.roomRepo.getById(widget.roomId!);
      if (room != null) {
        final loc = await app.locationRepo.getById(room.locationId);
        _elecPrice = loc?.elecPrice ?? AppConstants.defaultElecPrice;
        _waterPrice = loc?.waterPrice ?? AppConstants.defaultWaterPrice;
      }
    } else {
      _elecPrice = app.currentLocation?.elecPrice ??
          await app.settingsRepo.getElecPrice();
      _waterPrice = app.currentLocation?.waterPrice ??
          await app.settingsRepo.getWaterPrice();
    }
    if (widget.roomId != null) {
      final room = await app.roomRepo.getById(widget.roomId!);
      if (room != null) await _selectRoom(room);
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectRoom(Room room) async {
    final app = context.read<AppState>();
    final tenant = await app.tenantRepo.getCurrentByRoom(room.id!);
    final existing = await app.invoiceRepo
        .getByRoomAndMonth(room.id!, widget.month, widget.year);
    final prev = await app.invoiceRepo
        .getPreviousInvoice(room.id!, widget.month, widget.year);

    setState(() {
      _selectedRoom = room;
      _tenant = tenant;
      _existing = existing;
      _previousInvoice = prev;

      _rent.text = (existing?.rentFee ?? room.baseRent).toString();
      _internet.text =
          (existing?.internetFee ?? room.internetFee).toString();
      _elevator.text =
          (existing?.elevatorFee ?? room.elevatorFee).toString();
      _washing.text = (existing?.washingFee ?? room.washingFee).toString();

      _elecOld.text =
          (existing?.elecOld ?? prev?.elecNew ?? 0).toString();
      _elecNew.text = (existing?.elecNew ?? 0).toString();
      _waterOld.text =
          (existing?.waterOld ?? prev?.waterNew ?? 0).toString();
      _waterNew.text = (existing?.waterNew ?? 0).toString();
    });
  }

  int _i(TextEditingController c) => FormatUtils.parseInt(c.text);

  int get _elecUsed {
    final v = _i(_elecNew) - _i(_elecOld);
    return v < 0 ? 0 : v;
  }

  int get _waterUsed {
    final v = _i(_waterNew) - _i(_waterOld);
    return v < 0 ? 0 : v;
  }

  int get _elecFee => _elecUsed * _elecPrice;
  int get _waterFee => _waterUsed * _waterPrice;
  int get _total =>
      _i(_rent) + _i(_internet) + _i(_elevator) + _i(_washing) +
      _elecFee + _waterFee;

  Future<void> _save() async {
    if (_selectedRoom == null) return;
    if (_i(_elecNew) < _i(_elecOld)) {
      _showError('Số điện mới phải >= số cũ');
      return;
    }
    if (_i(_waterNew) < _i(_waterOld)) {
      _showError('Số nước mới phải >= số cũ');
      return;
    }

    final app = context.read<AppState>();
    final invoice = Invoice(
      id: _existing?.id,
      roomId: _selectedRoom!.id!,
      tenantId: _tenant?.id,
      month: widget.month,
      year: widget.year,
      rentFee: _i(_rent),
      internetFee: _i(_internet),
      elevatorFee: _i(_elevator),
      washingFee: _i(_washing),
      elecOld: _i(_elecOld),
      elecNew: _i(_elecNew),
      elecUnitPrice: _elecPrice,
      waterOld: _i(_waterOld),
      waterNew: _i(_waterNew),
      waterUnitPrice: _waterPrice,
      isPaid: _existing?.isPaid ?? false,
      paidDate: _existing?.paidDate,
      createdAt: _existing?.createdAt ?? DateTime.now(),
    );

    int id;
    if (invoice.id == null) {
      id = await app.invoiceRepo.insert(invoice);
    } else {
      await app.invoiceRepo.update(invoice);
      id = invoice.id!;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_existing == null
              ? 'Đã tạo hóa đơn'
              : 'Đã cập nhật hóa đơn')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null
            ? 'Tạo HĐ ${FormatUtils.monthYear(widget.month, widget.year)}'
            : 'Sửa HĐ ${FormatUtils.monthYear(widget.month, widget.year)}'),
      ),
      body: _selectedRoom == null ? _roomPicker(app) : _form(),
      bottomNavigationBar: _selectedRoom == null ? null : _buildBottomBar(),
    );
  }

  Widget _roomPicker(AppState app) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Chọn phòng để tạo hóa đơn',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...app.rooms.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(r.roomNumber,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
                title: Text('Phòng ${r.roomNumber}'),
                subtitle: Text(app.currentTenantByRoom[r.id]?.fullName ?? '-'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectRoom(r),
              ),
            )),
      ],
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        _buildSection(
          icon: Icons.electric_bolt,
          color: Colors.orange,
          title: 'Số điện',
          subtitle: '${FormatUtils.money(_elecPrice)}đ/kWh',
          oldCtrl: _elecOld,
          newCtrl: _elecNew,
          used: _elecUsed,
          fee: _elecFee,
          unit: 'kWh',
        ),
        const SizedBox(height: 12),
        _buildSection(
          icon: Icons.water_drop,
          color: Colors.blue,
          title: 'Số nước',
          subtitle: '${FormatUtils.money(_waterPrice)}đ/m³',
          oldCtrl: _waterOld,
          newCtrl: _waterNew,
          used: _waterUsed,
          fee: _waterFee,
          unit: 'm³',
        ),
        const SizedBox(height: 12),
        _buildFixedFeesCard(),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        if (_previousInvoice != null) ...[
          const SizedBox(height: 12),
          _buildPreviousCard(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_selectedRoom!.roomNumber,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tenant?.fullName ?? 'Chưa có khách',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                    'HĐ ${FormatUtils.monthName(widget.month, widget.year)}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (_existing != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Đã có',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required TextEditingController oldCtrl,
    required TextEditingController newCtrl,
    required int used,
    required int fee,
    required String unit,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _meterField(oldCtrl, 'Số cũ', color),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: color),
                ),
                Expanded(
                  child: _meterField(newCtrl, 'Số mới', color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('Số sử dụng:',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$used $unit',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const Spacer(),
                  Text('${FormatUtils.money(fee)}đ',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meterField(
      TextEditingController c, String label, Color color) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style:
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFixedFeesCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payments, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Khoản cố định',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            _moneyField(_rent, 'Tiền phòng', Icons.home),
            const SizedBox(height: 10),
            _moneyField(_internet, 'Mạng internet', Icons.wifi),
            const SizedBox(height: 10),
            _moneyField(_elevator, 'Thang máy, vệ sinh', Icons.elevator),
            const SizedBox(height: 10),
            _moneyField(_washing, 'Máy giặt', Icons.local_laundry_service),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(
      TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixText: 'đ',
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSummaryCard() {
    final items = <(String, int, IconData, Color)>[
      ('Tiền phòng', _i(_rent), Icons.home, Colors.blue),
      if (_i(_internet) > 0)
        ('Mạng internet', _i(_internet), Icons.wifi, Colors.purple),
      if (_i(_elevator) > 0)
        ('Thang máy, vệ sinh', _i(_elevator), Icons.elevator, Colors.teal),
      if (_i(_washing) > 0)
        ('Máy giặt', _i(_washing), Icons.local_laundry_service, Colors.indigo),
      ('Tiền điện ($_elecUsed kWh × ${FormatUtils.money(_elecPrice)}đ)',
          _elecFee, Icons.electric_bolt, Colors.orange),
      ('Tiền nước ($_waterUsed m³ × ${FormatUtils.money(_waterPrice)}đ)',
          _waterFee, Icons.water_drop, Colors.blue),
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Tổng kết hóa đơn',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(it.$3, size: 16, color: it.$4),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(it.$1,
                              style: const TextStyle(fontSize: 13))),
                      Text('${FormatUtils.money(it.$2)}đ',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const Divider(height: 22, thickness: 1),
            Row(
              children: [
                const Text('TỔNG CỘNG',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text('${FormatUtils.money(_total)}đ',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousCard() {
    final p = _previousInvoice!;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.amber.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                    'HĐ tháng trước (${FormatUtils.monthYear(p.month, p.year)})',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Điện: ${p.elecOld} → ${p.elecNew} (${p.elecUsed} kWh)  •  Nước: ${p.waterOld} → ${p.waterNew} (${p.waterUsed} m³)',
                style: const TextStyle(fontSize: 11)),
            Text('Tổng tháng trước: ${FormatUtils.money(p.total)}đ',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng cộng',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text('${FormatUtils.money(_total)}đ',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_existing == null ? 'Lưu HĐ' : 'Cập nhật'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
