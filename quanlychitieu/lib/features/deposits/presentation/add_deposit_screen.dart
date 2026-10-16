import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bank.dart';
import '../../../data/models/bank_deposit.dart';
import '../../../data/repositories/bank_repository.dart';
import '../../../data/repositories/deposit_repository.dart';
import '../../../services/notification_service.dart';
import '../../../data/repositories/settings_repository.dart';

class AddDepositScreen extends StatefulWidget {
  final BankDeposit? deposit;
  const AddDepositScreen({super.key, this.deposit});

  @override
  State<AddDepositScreen> createState() => _AddDepositScreenState();
}

class _AddDepositScreenState extends State<AddDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _bankRepo = BankRepository();
  final _depRepo = DepositRepository();
  final _settingsRepo = SettingsRepository();

  int? _bankId;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 90));
  List<Bank> _banks = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.deposit;
    if (d != null) {
      _bankId = d.bankId;
      _amountCtrl.text = d.amount.toStringAsFixed(0);
      _rateCtrl.text = d.interestRate?.toString() ?? '';
      _noteCtrl.text = d.note ?? '';
      _startDate = DateTime.parse(d.startDate);
      _dueDate = DateTime.parse(d.dueDate);
    }
    _bankRepo.getAll().then((b) => setState(() {
      _banks = b;
      if (_bankId == null && b.isNotEmpty) _bankId = b.first.id;
    }));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deposit == null ? 'Thêm sổ tiết kiệm' : 'Sửa sổ tiết kiệm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              value: _bankId,
              decoration: const InputDecoration(labelText: 'Ngân hàng *', border: OutlineInputBorder()),
              items: _banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
              onChanged: (v) => setState(() => _bankId = v),
              validator: (v) => v == null ? 'Chọn ngân hàng' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              decoration: const InputDecoration(labelText: 'Số tiền gốc *', suffixText: 'đ', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty || parseAmount(v) <= 0) ? 'Nhập số tiền hợp lệ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Lãi suất (%/năm, tùy chọn)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (p != null) setState(() => _startDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày gửi', border: OutlineInputBorder()),
                  child: Text(formatDate(_startDate)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime(2035));
                  if (p != null) setState(() => _dueDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày đáo hạn *', border: OutlineInputBorder()),
                  child: Text(formatDate(_dueDate)),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(widget.deposit == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final bank = _banks.firstWhere((b) => b.id == _bankId);
    final reminderDays = await _settingsRepo.getReminderDays();

    final dep = BankDeposit(
      id: widget.deposit?.id,
      bankId: _bankId!,
      amount: parseAmount(_amountCtrl.text),
      interestRate: _rateCtrl.text.trim().isEmpty ? null : double.tryParse(_rateCtrl.text),
      startDate: toIso(_startDate),
      dueDate: toIso(_dueDate),
      termMonths: _dueDate.difference(_startDate).inDays ~/ 30,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: widget.deposit?.createdAt ?? now,
      updatedAt: now,
    );

    int id;
    if (widget.deposit == null) {
      id = await _depRepo.insert(dep);
    } else {
      await _depRepo.update(dep);
      id = widget.deposit!.id!;
    }

    await NotificationService.scheduleDepositReminder(
      id: id,
      bankName: bank.name,
      amount: dep.amount,
      dueDate: _dueDate,
      reminderDays: reminderDays,
    );

    if (mounted) Navigator.pop(context);
  }
}
