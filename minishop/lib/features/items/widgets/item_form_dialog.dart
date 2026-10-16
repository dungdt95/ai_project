import 'package:flutter/material.dart';

import '../../../data/models/category.dart';
import '../../../data/models/item.dart';

class ItemFormDialog extends StatefulWidget {
  final Item? existing;
  final List<ProductCategory> categories;

  const ItemFormDialog({super.key, this.existing, required this.categories});

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _unitCtrl;
  int? _categoryId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toString() : '',
    );
    _unitCtrl = TextEditingController(text: existing?.unit ?? 'ly');
    _categoryId = existing?.categoryId;
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Sửa mặt hàng' : 'Thêm mặt hàng'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên mặt hàng'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nhập tên mặt hàng'
                    : null,
              ),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Nhập giá hợp lệ';
                  return null;
                },
              ),
              TextFormField(
                controller: _unitCtrl,
                decoration:
                    const InputDecoration(labelText: 'Đơn vị (ly, chai...)'),
              ),
              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Chưa phân loại'),
                  ),
                  ...widget.categories.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang bán'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = Item(
      id: widget.existing?.id,
      categoryId: _categoryId,
      name: _nameCtrl.text.trim(),
      price: int.parse(_priceCtrl.text),
      unit: _unitCtrl.text.trim().isEmpty ? 'ly' : _unitCtrl.text.trim(),
      isActive: _isActive,
      imagePath: widget.existing?.imagePath,
    );
    Navigator.of(context).pop(result);
  }
}
