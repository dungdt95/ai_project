import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';

class MeterReadingScreen extends StatefulWidget {
  final int month;
  final int year;
  const MeterReadingScreen({
    super.key,
    required this.month,
    required this.year,
  });

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _RoomMeter {
  final Room room;
  final Invoice? existing;
  final TextEditingController elecOld;
  final TextEditingController elecNew;
  final TextEditingController waterOld;
  final TextEditingController waterNew;

  _RoomMeter({
    required this.room,
    required this.existing,
    required int prevElec,
    required int prevWater,
  })  : elecOld = TextEditingController(
            text: (existing?.elecOld ?? prevElec).toString()),
        elecNew = TextEditingController(
            text: existing?.elecNew.toString() ?? ''),
        waterOld = TextEditingController(
            text: (existing?.waterOld ?? prevWater).toString()),
        waterNew = TextEditingController(
            text: existing?.waterNew.toString() ?? '');

  void dispose() {
    elecOld.dispose();
    elecNew.dispose();
    waterOld.dispose();
    waterNew.dispose();
  }
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  late int _month;
  late int _year;
  List<_RoomMeter> _items = [];
  int _elecPrice = AppConstants.defaultElecPrice;
  int _waterPrice = AppConstants.defaultWaterPrice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _year = widget.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    _elecPrice = await app.settingsRepo.getElecPrice();
    _waterPrice = await app.settingsRepo.getWaterPrice();

    final items = <_RoomMeter>[];
    for (final room in app.rooms) {
      if (!room.isOccupied) continue;
      final existing = await app.invoiceRepo
          .getByRoomAndMonth(room.id!, _month, _year);
      final prev = await app.invoiceRepo
          .getPreviousInvoice(room.id!, _month, _year);
      items.add(_RoomMeter(
        room: room,
        existing: existing,
        prevElec: prev?.elecNew ?? 0,
        prevWater: prev?.waterNew ?? 0,
      ));
    }
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _changeMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(initial: DateTime(_year, _month)),
    );
    if (picked != null) {
      for (final i in _items) {
        i.dispose();
      }
      setState(() {
        _month = picked.month;
        _year = picked.year;
        _loading = true;
        _items = [];
      });
      await _load();
    }
  }

  int _elecOld(_RoomMeter m) => FormatUtils.parseInt(m.elecOld.text);
  int _elecNew(_RoomMeter m) => FormatUtils.parseInt(m.elecNew.text);
  int _waterOld(_RoomMeter m) => FormatUtils.parseInt(m.waterOld.text);
  int _waterNew(_RoomMeter m) => FormatUtils.parseInt(m.waterNew.text);

  int _elecUsed(_RoomMeter m) {
    final v = _elecNew(m) - _elecOld(m);
    return v < 0 ? 0 : v;
  }

  int _waterUsed(_RoomMeter m) {
    final v = _waterNew(m) - _waterOld(m);
    return v < 0 ? 0 : v;
  }

  int _elecFee(_RoomMeter m) => _elecUsed(m) * _elecPrice;
  int _waterFee(_RoomMeter m) => _waterUsed(m) * _waterPrice;

  int _itemTotal(_RoomMeter m) {
    return m.room.baseRent +
        m.room.internetFee +
        m.room.elevatorFee +
        m.room.washingFee +
        _elecFee(m) +
        _waterFee(m);
  }

  bool _hasInput(_RoomMeter m) => m.elecNew.text.trim().isNotEmpty ||
      m.waterNew.text.trim().isNotEmpty;

  Future<void> _saveAll() async {
    final app = context.read<AppState>();
    int saved = 0;
    final invalidRooms = <String>[];

    for (final m in _items) {
      if (!_hasInput(m)) continue;
      final eOld = _elecOld(m);
      final eNew = _elecNew(m);
      final wOld = _waterOld(m);
      final wNew = _waterNew(m);
      if (eNew < eOld || wNew < wOld) {
        invalidRooms.add(m.room.roomNumber);
        continue;
      }

      final tenant = await app.tenantRepo.getCurrentByRoom(m.room.id!);
      final invoice = Invoice(
        id: m.existing?.id,
        roomId: m.room.id!,
        tenantId: tenant?.id,
        month: _month,
        year: _year,
        rentFee: m.existing?.rentFee ?? m.room.baseRent,
        internetFee: m.existing?.internetFee ?? m.room.internetFee,
        elevatorFee: m.existing?.elevatorFee ?? m.room.elevatorFee,
        washingFee: m.existing?.washingFee ?? m.room.washingFee,
        elecOld: eOld,
        elecNew: eNew,
        elecUnitPrice: _elecPrice,
        waterOld: wOld,
        waterNew: wNew,
        waterUnitPrice: _waterPrice,
        isPaid: m.existing?.isPaid ?? false,
        paidDate: m.existing?.paidDate,
        createdAt: m.existing?.createdAt ?? DateTime.now(),
      );

      if (invoice.id == null) {
        await app.invoiceRepo.insert(invoice);
      } else {
        await app.invoiceRepo.update(invoice);
      }
      saved++;
    }

    if (!mounted) return;
    final msg = invalidRooms.isNotEmpty
        ? 'Đã lưu $saved phòng. Lỗi (số mới < số cũ): ${invalidRooms.join(', ')}'
        : 'Đã lưu $saved phòng';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (invalidRooms.isEmpty && saved > 0) {
      Navigator.of(context).pop(true);
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filledCount = _items.where(_hasInput).length;
    final monthTotal =
        _items.where(_hasInput).fold<int>(0, (s, m) => s + _itemTotal(m));

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _changeMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ghi số ${FormatUtils.monthYear(_month, _year)}'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPriceBar(filledCount),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, idx) => _buildRoomCard(_items[idx]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(filledCount, monthTotal),
    );
  }

  Widget _buildPriceBar(int filledCount) {
    return Container(
      color: AppColors.primary.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.electric_bolt, color: Colors.orange, size: 18),
          const SizedBox(width: 4),
          Text('${FormatUtils.money(_elecPrice)}đ/kWh',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          const Icon(Icons.water_drop, color: Colors.blue, size: 18),
          const SizedBox(width: 4),
          Text('${FormatUtils.money(_waterPrice)}đ/m³',
              style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: filledCount > 0 ? AppColors.primary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$filledCount/${_items.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: filledCount > 0 ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(_RoomMeter m) {
    final tenant = context.read<AppState>().tenantOf(m.room);
    final hasInput = _hasInput(m);
    return Card(
      margin: EdgeInsets.zero,
      elevation: hasInput ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasInput
              ? AppColors.primary.withOpacity(0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(m.room.roomNumber,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tenant?.fullName ?? 'Trống',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (m.existing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Đã có HĐ',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Điện
            _buildMeterSection(
              icon: Icons.electric_bolt,
              iconColor: Colors.orange,
              label: 'Điện',
              oldCtrl: m.elecOld,
              newCtrl: m.elecNew,
              used: _elecUsed(m),
              fee: _elecFee(m),
              unit: 'kWh',
              unitPrice: _elecPrice,
            ),
            const SizedBox(height: 10),

            // Nước
            _buildMeterSection(
              icon: Icons.water_drop,
              iconColor: Colors.blue,
              label: 'Nước',
              oldCtrl: m.waterOld,
              newCtrl: m.waterNew,
              used: _waterUsed(m),
              fee: _waterFee(m),
              unit: 'm³',
              unitPrice: _waterPrice,
            ),

            // Breakdown chi tiết khi có input
            if (hasInput) ...[
              const SizedBox(height: 12),
              _buildBreakdown(m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeterSection({
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextEditingController oldCtrl,
    required TextEditingController newCtrl,
    required int used,
    required int fee,
    required String unit,
    required int unitPrice,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: iconColor.withOpacity(0.9))),
              const Spacer(),
              Text('${FormatUtils.money(unitPrice)}đ/$unit',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _meterInput(oldCtrl, 'Số cũ', iconColor),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: _meterInput(newCtrl, 'Số mới', iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$used $unit',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
              ),
              const Spacer(),
              Text('${FormatUtils.money(fee)}đ',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: iconColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meterInput(
      TextEditingController c, String hint, Color color) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBreakdown(_RoomMeter m) {
    final r = m.room;
    final items = <(String, int, IconData?, Color?)>[
      ('Tiền phòng', r.baseRent, Icons.home, Colors.blue),
      if (r.internetFee > 0)
        ('Mạng internet', r.internetFee, Icons.wifi, Colors.purple),
      if (r.elevatorFee > 0)
        ('Thang máy, vệ sinh', r.elevatorFee, Icons.elevator, Colors.teal),
      if (r.washingFee > 0)
        ('Máy giặt', r.washingFee, Icons.local_laundry_service, Colors.indigo),
      ('Tiền điện (${_elecUsed(m)} kWh)', _elecFee(m), Icons.electric_bolt,
          Colors.orange),
      ('Tiền nước (${_waterUsed(m)} m³)', _waterFee(m), Icons.water_drop,
          Colors.blue),
    ];
    final total = _itemTotal(m);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Tổng kết hóa đơn',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    if (it.$3 != null)
                      Icon(it.$3!, size: 13, color: it.$4 ?? Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(it.$1,
                            style: const TextStyle(fontSize: 13))),
                    Text('${FormatUtils.money(it.$2)}đ',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            children: [
              const Text('TỔNG CỘNG',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${FormatUtils.money(total)}đ',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int filledCount, int monthTotal) {
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
                  const Text('Tổng tạm tính',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text('${FormatUtils.money(monthTotal)}đ',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: filledCount == 0 ? null : _saveAll,
              icon: const Icon(Icons.save),
              label: Text('Lưu $filledCount HĐ'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPicker extends StatefulWidget {
  final DateTime initial;
  const _MonthPicker({required this.initial});
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
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
            onPressed: () =>
                Navigator.pop(context, DateTime(_year, _month)),
            child: const Text('Chọn')),
      ],
    );
  }
}
