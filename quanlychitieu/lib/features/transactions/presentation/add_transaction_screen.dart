import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../core/utils/payment_method.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/category_repository.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final String? initialType;       // 'expense' | 'income'
  final int? initialCategoryId;    // pre-select khi click từ grid icon

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.initialType,
    this.initialCategoryId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _txRepo = TransactionRepository();
  final _catRepo = CategoryRepository();

  String _type = 'expense';
  int? _categoryId;
  DateTime _date = DateTime.now();
  String _paymentMethod = PaymentMethods.cash;
  List<Category> _categories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _amountCtrl.text = t.amount.toStringAsFixed(0);
      _noteCtrl.text = t.note ?? '';
      _categoryId = t.categoryId;
      _date = DateTime.parse(t.date);
      _paymentMethod = t.paymentMethod ?? PaymentMethods.cash;
    } else {
      if (widget.initialType != null) _type = widget.initialType!;
      if (widget.initialCategoryId != null) _categoryId = widget.initialCategoryId;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _catRepo.getAll(type: _type);
    setState(() => _categories = cats);
    // Chỉ set default nếu chưa có categoryId được truyền vào
    if (_categoryId == null && cats.isNotEmpty) {
      setState(() => _categoryId = cats.first.id);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Chi tiêu'), icon: Icon(Icons.remove_circle_outline)),
                ButtonSegment(value: 'income', label: Text('Thu nhập'), icon: Icon(Icons.add_circle_outline)),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() { _type = s.first; _categoryId = null; });
                _loadCategories();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              decoration: const InputDecoration(
                labelText: 'Số tiền *',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập số tiền';
                if (parseAmount(v) <= 0) return 'Số tiền không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Danh mục *', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(children: [
                  Icon(iconFromString(c.icon), size: 18,
                      color: _type == 'expense' ? AppColors.expense : AppColors.income),
                  const SizedBox(width: 8),
                  Text(c.name),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Chọn danh mục' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Ngày', border: OutlineInputBorder()),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Loại tiền', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: PaymentMethods.all
                  .map((m) => ButtonSegment(
                        value: m,
                        label: Text(PaymentMethods.label(m)),
                        icon: Icon(PaymentMethods.icon(m)),
                      ))
                  .toList(),
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
            ),
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
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.transaction == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final tx = Transaction(
      id: widget.transaction?.id,
      type: _type,
      amount: parseAmount(_amountCtrl.text),
      categoryId: _categoryId!,
      date: toIso(_date),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      paymentMethod: _paymentMethod,
      createdAt: widget.transaction?.createdAt ?? now,
      updatedAt: now,
    );
    if (widget.transaction == null) {
      await _txRepo.insert(tx);
    } else {
      await _txRepo.update(tx);
    }
    if (mounted) Navigator.pop(context);
  }
}
