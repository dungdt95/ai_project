import 'package:flutter/material.dart';

import '../../../core/utils/bank_directory.dart';
import '../../../data/models/bank_account.dart';

const _otherBankKey = '__other__';

class BankAccountFormDialog extends StatefulWidget {
  final BankAccount? existing;

  const BankAccountFormDialog({super.key, this.existing});

  @override
  State<BankAccountFormDialog> createState() => _BankAccountFormDialogState();
}

class _BankAccountFormDialogState extends State<BankAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankBinCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _accountNameCtrl;
  late String _selectedBankKey;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final matched = bankDirectory.where((b) => b.name == existing?.bankName);
    _selectedBankKey = matched.isNotEmpty ? matched.first.name : _otherBankKey;

    _bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    _bankBinCtrl = TextEditingController(text: existing?.bankBin ?? '');
    _accountNumberCtrl =
        TextEditingController(text: existing?.accountNumber ?? '');
    _accountNameCtrl = TextEditingController(text: existing?.accountName ?? '');
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _bankBinCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  void _onBankSelected(String? key) {
    if (key == null) return;
    setState(() {
      _selectedBankKey = key;
      if (key != _otherBankKey) {
        final bank = bankDirectory.firstWhere((b) => b.name == key);
        _bankNameCtrl.text = bank.name;
        _bankBinCtrl.text = bank.bin;
      } else {
        _bankNameCtrl.clear();
        _bankBinCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final isOther = _selectedBankKey == _otherBankKey;

    return AlertDialog(
      title: Text(
          isEditing ? 'Sửa tài khoản ngân hàng' : 'Thêm tài khoản ngân hàng'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedBankKey,
                decoration: const InputDecoration(labelText: 'Ngân hàng'),
                items: [
                  ...bankDirectory.map(
                    (b) => DropdownMenuItem(value: b.name, child: Text(b.name)),
                  ),
                  const DropdownMenuItem(
                      value: _otherBankKey, child: Text('Khác...')),
                ],
                onChanged: _onBankSelected,
              ),
              if (isOther) ...[
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên ngân hàng'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nhập tên ngân hàng'
                      : null,
                ),
                TextFormField(
                  controller: _bankBinCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Mã BIN ngân hàng (Napas)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập mã BIN' : null,
                ),
              ],
              TextFormField(
                controller: _accountNumberCtrl,
                decoration: const InputDecoration(labelText: 'Số tài khoản'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nhập số tài khoản'
                    : null,
              ),
              TextFormField(
                controller: _accountNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản (không dấu, IN HOA)'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nhập tên chủ tài khoản'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đặt làm mặc định'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
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
    final result = BankAccount(
      id: widget.existing?.id,
      bankBin: _bankBinCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim(),
      accountName: _accountNameCtrl.text.trim().toUpperCase(),
      isDefault: _isDefault,
    );
    Navigator.of(context).pop(result);
  }
}
