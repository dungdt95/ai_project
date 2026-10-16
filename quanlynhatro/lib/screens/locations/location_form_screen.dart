import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/location.dart';
import '../../providers/app_state.dart';

class LocationFormScreen extends StatefulWidget {
  final Location? location;
  const LocationFormScreen({super.key, this.location});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _name;
  late TextEditingController _address;
  late TextEditingController _ownerName;
  late TextEditingController _ownerPhone;
  late TextEditingController _bankName;
  late TextEditingController _bankAccount;
  late TextEditingController _bankHolder;
  late TextEditingController _transferTemplate;
  late TextEditingController _elecPrice;
  late TextEditingController _waterPrice;
  late TextEditingController _invoiceFooter;

  String? _qrImagePath;
  bool _saving = false;

  bool get _isEdit => widget.location != null;

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    _name = TextEditingController(text: loc?.name ?? '');
    _address = TextEditingController(text: loc?.address ?? '');
    _ownerName = TextEditingController(text: loc?.ownerName ?? '');
    _ownerPhone = TextEditingController(text: loc?.ownerPhone ?? '');
    _bankName = TextEditingController(text: loc?.bankName ?? '');
    _bankAccount = TextEditingController(text: loc?.bankAccount ?? '');
    _bankHolder = TextEditingController(text: loc?.bankHolder ?? '');
    _transferTemplate =
        TextEditingController(text: loc?.transferTemplate ?? '');
    _elecPrice = TextEditingController(
        text: (loc?.elecPrice ?? AppConstants.defaultElecPrice).toString());
    _waterPrice = TextEditingController(
        text: (loc?.waterPrice ?? AppConstants.defaultWaterPrice).toString());
    _invoiceFooter = TextEditingController(text: loc?.invoiceFooter ?? '');
    _qrImagePath = loc?.qrImagePath;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _address, _ownerName, _ownerPhone, _bankName,
      _bankAccount, _bankHolder, _transferTemplate, _elecPrice,
      _waterPrice, _invoiceFooter,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickQrImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    // Copy ảnh vào app documents để tồn tại lâu dài
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(srcPath);
    final destName = 'qr_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, destName));
    await File(srcPath).copy(dest.path);

    setState(() => _qrImagePath = dest.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final app = context.read<AppState>();
      final loc = Location(
        id: widget.location?.id,
        name: _name.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        ownerName:
            _ownerName.text.trim().isEmpty ? null : _ownerName.text.trim(),
        ownerPhone:
            _ownerPhone.text.trim().isEmpty ? null : _ownerPhone.text.trim(),
        bankName:
            _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        bankAccount: _bankAccount.text.trim().isEmpty
            ? null
            : _bankAccount.text.trim(),
        bankHolder: _bankHolder.text.trim().isEmpty
            ? null
            : _bankHolder.text.trim(),
        transferTemplate: _transferTemplate.text.trim().isEmpty
            ? null
            : _transferTemplate.text.trim(),
        elecPrice: int.tryParse(_elecPrice.text) ?? AppConstants.defaultElecPrice,
        waterPrice:
            int.tryParse(_waterPrice.text) ?? AppConstants.defaultWaterPrice,
        invoiceFooter: _invoiceFooter.text.trim().isEmpty
            ? null
            : _invoiceFooter.text.trim(),
        qrImagePath: _qrImagePath,
        sortOrder: widget.location?.sortOrder ?? 0,
      );

      if (_isEdit) {
        await app.locationRepo.update(loc);
      } else {
        await app.locationRepo.insert(loc);
      }
      await app.reloadLocations();

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final app = context.read<AppState>();
    final hasRooms = await app.locationRepo.hasRooms(widget.location!.id!);
    if (!mounted) return;
    if (hasRooms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không thể xóa: địa điểm này vẫn còn phòng.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa địa điểm'),
        content:
            Text('Xóa "${widget.location!.name}"? Hành động này không thể hoàn tác.'),
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
    if (ok != true || !mounted) return;

    await app.locationRepo.delete(widget.location!.id!);
    await app.reloadLocations();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa địa điểm' : 'Thêm địa điểm'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Thông tin tòa nhà'),
            _field(_name, 'Tên địa điểm *', required: true),
            _field(_address, 'Địa chỉ'),
            const SizedBox(height: 16),
            _section('Thông tin chủ nhà'),
            _field(_ownerName, 'Tên chủ nhà'),
            _field(_ownerPhone, 'SĐT / Zalo', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _section('Thông tin thanh toán'),
            _field(_bankName, 'Tên ngân hàng'),
            _field(_bankAccount, 'Số tài khoản',
                keyboard: TextInputType.number),
            _field(_bankHolder, 'Tên chủ tài khoản'),
            _field(_transferTemplate, 'Mẫu nội dung CK (dùng [PHONG])'),
            const SizedBox(height: 16),
            _section('Ảnh QR thanh toán'),
            _buildQrPicker(),
            const SizedBox(height: 16),
            _section('Giá dịch vụ'),
            _field(_elecPrice, 'Giá điện (đ/kWh)',
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly]),
            _field(_waterPrice, 'Giá nước (đ/m³)',
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 16),
            _section('Ghi chú cuối hóa đơn'),
            _field(_invoiceFooter, 'Ghi chú', maxLines: 4),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
            : null,
      ),
    );
  }

  Widget _buildQrPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_qrImagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_qrImagePath!),
                width: 120, height: 120, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickQrImage,
                icon: const Icon(Icons.image),
                label: const Text('Đổi ảnh QR'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _qrImagePath = null),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _pickQrImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Chọn ảnh QR'),
          ),
          const SizedBox(height: 4),
          const Text('Nếu không chọn, sẽ dùng QR mặc định của app.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
