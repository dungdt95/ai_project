import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';

class RoomFormScreen extends StatefulWidget {
  final Room? room;
  final int locationId;
  const RoomFormScreen({super.key, this.room, this.locationId = 1});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _number;
  late TextEditingController _floor;
  late TextEditingController _rent;
  late TextEditingController _internet;
  late TextEditingController _elevator;
  late TextEditingController _washing;
  late TextEditingController _notes;
  late String _status;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _number = TextEditingController(text: r?.roomNumber ?? '');
    _floor = TextEditingController(text: r?.floor?.toString() ?? '');
    _rent = TextEditingController(text: r?.baseRent.toString() ?? '');
    _internet = TextEditingController(text: r?.internetFee.toString() ?? '0');
    _elevator = TextEditingController(text: r?.elevatorFee.toString() ?? '0');
    _washing = TextEditingController(text: r?.washingFee.toString() ?? '0');
    _notes = TextEditingController(text: r?.notes ?? '');
    _status = r?.status ?? 'occupied';
  }

  @override
  void dispose() {
    _number.dispose();
    _floor.dispose();
    _rent.dispose();
    _internet.dispose();
    _elevator.dispose();
    _washing.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final room = Room(
      id: widget.room?.id,
      locationId: widget.room?.locationId ?? widget.locationId,
      roomNumber: _number.text.trim(),
      floor: int.tryParse(_floor.text.trim()),
      baseRent: FormatUtils.parseInt(_rent.text),
      internetFee: FormatUtils.parseInt(_internet.text),
      elevatorFee: FormatUtils.parseInt(_elevator.text),
      washingFee: FormatUtils.parseInt(_washing.text),
      status: _status,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (room.id == null) {
      await app.roomRepo.insert(room);
    } else {
      await app.roomRepo.update(room);
    }
    await app.reloadRooms();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text(
            'Xóa phòng ${widget.room!.roomNumber} cùng dữ liệu khách & hóa đơn của phòng?'),
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
    await app.roomRepo.delete(widget.room!.id!);
    await app.reloadRooms();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room == null ? 'Thêm phòng' : 'Sửa phòng'),
        actions: [
          if (widget.room != null)
            IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(labelText: 'Số phòng *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _floor,
              decoration: const InputDecoration(labelText: 'Tầng'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            _moneyField(_rent, 'Tiền phòng (VNĐ) *', required: true),
            const SizedBox(height: 12),
            _moneyField(_internet, 'Phí mạng internet (VNĐ)'),
            const SizedBox(height: 12),
            _moneyField(_elevator, 'Phí thang máy, vệ sinh (VNĐ)'),
            const SizedBox(height: 12),
            _moneyField(_washing, 'Phí máy giặt (VNĐ)'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: const [
                DropdownMenuItem(value: 'occupied', child: Text('Đang thuê')),
                DropdownMenuItem(value: 'vacant', child: Text('Trống')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'occupied'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(TextEditingController c, String label,
      {bool required = false}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
          : null,
    );
  }
}
