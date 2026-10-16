import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/location.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import 'invoice_create_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Invoice? _invoice;
  Room? _room;
  Tenant? _tenant;
  Location? _location;
  Map<String, String> _settings = {};
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final invoices = await app.invoiceRepo.getAll();
    final inv = invoices.firstWhere(
      (i) => i.id == widget.invoiceId,
      orElse: () => Invoice(roomId: 0, month: 1, year: 2026, rentFee: 0),
    );
    final room = await app.roomRepo.getById(inv.roomId);
    final tenant = inv.tenantId != null
        ? (await app.tenantRepo.getAll())
            .where((t) => t.id == inv.tenantId)
            .cast<Tenant?>()
            .firstWhere((_) => true, orElse: () => null)
        : await app.tenantRepo.getCurrentByRoom(inv.roomId);
    final location = room != null
        ? await app.locationRepo.getById(room.locationId)
        : null;
    final settings = await app.settingsRepo.getAll();
    if (mounted) {
      setState(() {
        _invoice = inv;
        _room = room;
        _tenant = tenant;
        _location = location;
        _settings = settings;
      });
    }
  }

  Future<void> _togglePaid() async {
    final app = context.read<AppState>();
    final updated = _invoice!.copyWith(
      isPaid: !_invoice!.isPaid,
      paidDate: !_invoice!.isPaid ? DateTime.now() : null,
    );
    await app.invoiceRepo.update(updated);
    setState(() => _invoice = updated);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa hóa đơn'),
        content: const Text('Xóa hóa đơn này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    await app.invoiceRepo.delete(widget.invoiceId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _shareAsImage() async {
    if (_invoice == null || _room == null) return;
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fileName =
          'hoadon_${_room!.roomNumber}_${_invoice!.month}_${_invoice!.year}.png';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            'Hóa đơn phòng ${_room!.roomNumber} - ${FormatUtils.monthName(_invoice!.month, _invoice!.year)}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_invoice == null || _room == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final inv = _invoice!;
    final room = _room!;
    final building = _location?.name ??
        _settings[AppConstants.keyBuildingName] ??
        AppConstants.defaultBuildingName;
    final ownerName = _location?.ownerName ??
        _settings[AppConstants.keyOwnerName] ??
        AppConstants.defaultOwnerName;
    final bankAccount = _location?.bankAccount ??
        _settings[AppConstants.keyBankAccount] ??
        AppConstants.defaultBankAccount;
    final bankName = _location?.bankName ??
        _settings[AppConstants.keyBankName] ??
        AppConstants.defaultBankName;
    final transferTemplate = (_location?.transferTemplate ??
            _settings[AppConstants.keyTransferTemplate] ??
            AppConstants.defaultTransferTemplate)
        .replaceAll('[PHONG]', room.roomNumber);
    final ownerPhone = _location?.ownerPhone ??
        _settings[AppConstants.keyOwnerPhone] ??
        AppConstants.defaultOwnerPhone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết hóa đơn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InvoiceCreateScreen(
                    month: inv.month, year: inv.year, roomId: room.id),
              ));
              await _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              color: AppColors.bgLight,
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HÓA ĐƠN TIỀN NHÀ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(
                            FormatUtils.monthName(inv.month, inv.year)
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        Text(building,
                            style: const TextStyle(color: Colors.white)),
                        Text(
                            'Phòng ${room.roomNumber} - ${_tenant?.fullName ?? '-'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _itemRow('Tiền phòng', inv.rentFee),
                          if (inv.internetFee > 0)
                            _itemRow('Mạng internet', inv.internetFee),
                          if (inv.elevatorFee > 0)
                            _itemRow('Thang máy, vệ sinh', inv.elevatorFee),
                          if (inv.washingFee > 0)
                            _itemRow('Máy giặt', inv.washingFee),
                          _meterRow(
                            'Điện',
                            inv.elecOld,
                            inv.elecNew,
                            inv.elecUsed,
                            inv.elecUnitPrice,
                            inv.elecFee,
                            'kWh',
                          ),
                          _meterRow(
                            'Nước',
                            inv.waterOld,
                            inv.waterNew,
                            inv.waterUsed,
                            inv.waterUnitPrice,
                            inv.waterFee,
                            'm³',
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Text('TỔNG CỘNG',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('${FormatUtils.money(inv.total)}đ',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Thông tin thanh toán',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Chủ nhà: $ownerName'),
                                Text('Ngân hàng: $bankName'),
                                Text('STK: $bankAccount'),
                                Text('Nội dung CK: "$transferTemplate"'),
                                Text('Zalo: $ownerPhone'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _location?.qrImagePath != null
                                    ? Image.file(
                                        File(_location!.qrImagePath!),
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.asset('assets/images/qr.png',
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 4),
                              const Text('Quét QR thanh toán',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _togglePaid,
                  icon: Icon(inv.isPaid
                      ? Icons.undo
                      : Icons.check_circle_outline),
                  label: Text(inv.isPaid
                      ? 'Đánh dấu chưa thu'
                      : 'Đánh dấu đã thu'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: inv.isPaid
                          ? Colors.grey
                          : AppColors.statusOccupied),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sharing ? null : _shareAsImage,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: Text(_sharing ? 'Đang tạo ảnh...' : 'Chia sẻ ảnh hóa đơn'),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${FormatUtils.money(value)}đ'),
        ],
      ),
    );
  }

  Widget _meterRow(String label, int old, int curr, int used, int price,
      int fee, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('$label sinh hoạt',
                      style: const TextStyle(fontWeight: FontWeight.w500))),
              Text('${FormatUtils.money(fee)}đ'),
            ],
          ),
          Text(
            '   $old → $curr  ($used $unit × ${FormatUtils.money(price)}đ)',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
