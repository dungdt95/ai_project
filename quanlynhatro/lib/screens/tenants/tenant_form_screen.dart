import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/tenant.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';

class TenantFormScreen extends StatefulWidget {
  final int roomId;
  final Tenant? tenant;
  const TenantFormScreen({super.key, required this.roomId, this.tenant});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _idCard;
  late TextEditingController _deposit;
  late TextEditingController _notes;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    _name = TextEditingController(text: t?.fullName ?? '');
    _phone = TextEditingController(text: t?.phone ?? '');
    _idCard = TextEditingController(text: t?.idCard ?? '');
    _deposit = TextEditingController(text: t?.deposit.toString() ?? '0');
    _notes = TextEditingController(text: t?.notes ?? '');
    _start = t?.contractStart;
    _end = t?.contractEnd;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idCard.dispose();
    _deposit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final tenant = Tenant(
      id: widget.tenant?.id,
      roomId: widget.roomId,
      fullName: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      idCard: _idCard.text.trim().isEmpty ? null : _idCard.text.trim(),
      contractStart: _start,
      contractEnd: _end,
      deposit: FormatUtils.parseInt(_deposit.text),
      isCurrent: true,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (tenant.id == null) {
      await app.tenantRepo.markPreviousAsLeft(widget.roomId);
      await app.tenantRepo.insert(tenant);
    } else {
      await app.tenantRepo.update(tenant);
    }
    await app.reloadRooms();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _markLeft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đánh dấu đã trả phòng'),
        content: Text(
            'Đánh dấu khách ${widget.tenant!.fullName} đã trả phòng? Phòng sẽ trống.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    await app.tenantRepo
        .update(widget.tenant!.copyWith(isCurrent: false));
    await app.reloadRooms();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenant == null ? 'Thêm khách thuê' : 'Sửa khách'),
        actions: [
          if (widget.tenant != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Đã trả phòng',
              onPressed: _markLeft,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ tên *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]'))
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _idCard,
              decoration: const InputDecoration(labelText: 'CCCD/CMND'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  'Ngày ký HĐ: ${_start != null ? FormatUtils.date(_start) : 'Chưa chọn'}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  'Ngày hết HĐ: ${_end != null ? FormatUtils.date(_end) : 'Chưa chọn'}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deposit,
              decoration: const InputDecoration(labelText: 'Tiền cọc (VNĐ)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
}
