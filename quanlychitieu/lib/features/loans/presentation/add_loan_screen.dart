import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/borrower.dart';
import '../../../data/models/loan.dart';
import '../../../data/repositories/borrower_repository.dart';
import '../../../data/repositories/loan_repository.dart';
import '../../../services/notification_service.dart';

class AddLoanScreen extends StatefulWidget {
  final Loan? loan;
  final int? preselectedBorrowerId;
  const AddLoanScreen({super.key, this.loan, this.preselectedBorrowerId});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _newBorrowerCtrl = TextEditingController();
  final _borrowerRepo = BorrowerRepository();
  final _loanRepo = LoanRepository();

  int? _borrowerId;
  DateTime _loanDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 30));
  List<Borrower> _borrowers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.loan;
    if (l != null) {
      _borrowerId = l.borrowerId;
      _amountCtrl.text = l.amount.toStringAsFixed(0);
      _rateCtrl.text = l.interestRate > 0 ? l.interestRate.toString() : '';
      _noteCtrl.text = l.note ?? '';
      _loanDate = DateTime.parse(l.loanDate);
      _returnDate = DateTime.parse(l.expectedReturnDate);
    } else if (widget.preselectedBorrowerId != null) {
      _borrowerId = widget.preselectedBorrowerId;
    }
    _loadBorrowers();
  }

  Future<void> _loadBorrowers() async {
    final list = await _borrowerRepo.getAll();
    setState(() {
      _borrowers = list;
      if (_borrowerId == null && list.isNotEmpty) _borrowerId = list.first.id;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    _newBorrowerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.loan == null ? 'Thêm khoản vay' : 'Sửa khoản vay')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _borrowerId,
                    decoration: const InputDecoration(labelText: 'Người vay *', border: OutlineInputBorder()),
                    items: _borrowers.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setState(() => _borrowerId = v),
                    validator: (v) => v == null ? 'Chọn người vay' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Thêm người vay mới',
                  onPressed: _showAddBorrowerDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              decoration: const InputDecoration(labelText: 'Số tiền cho vay *', suffixText: 'đ', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty || parseAmount(v) <= 0) ? 'Nhập số tiền hợp lệ' : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(context: context, initialDate: _loanDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (p != null) setState(() => _loanDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày cho vay', border: OutlineInputBorder()),
                  child: Text(formatDate(_loanDate)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(context: context, initialDate: _returnDate, firstDate: DateTime.now(), lastDate: DateTime(2035));
                  if (p != null) setState(() => _returnDate = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày dự kiến trả *', border: OutlineInputBorder()),
                  child: Text(formatDate(_returnDate)),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Lãi suất (%/năm, tùy chọn)', border: OutlineInputBorder()),
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
              child: Text(widget.loan == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBorrowerDialog() async {
    _newBorrowerCtrl.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm người vay mới'),
        content: TextField(
          controller: _newBorrowerCtrl,
          decoration: const InputDecoration(labelText: 'Tên người vay', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _newBorrowerCtrl.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final id = await _borrowerRepo.insert(Borrower(name: name));
      await _loadBorrowers();
      setState(() => _borrowerId = id);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final borrower = _borrowers.firstWhere((b) => b.id == _borrowerId);
    final loan = Loan(
      id: widget.loan?.id,
      borrowerId: _borrowerId!,
      amount: parseAmount(_amountCtrl.text),
      loanDate: toIso(_loanDate),
      expectedReturnDate: toIso(_returnDate),
      interestRate: double.tryParse(_rateCtrl.text) ?? 0,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: widget.loan?.createdAt ?? now,
      updatedAt: now,
    );

    int id;
    if (widget.loan == null) {
      id = await _loanRepo.insert(loan);
    } else {
      await _loanRepo.update(loan);
      id = widget.loan!.id!;
    }

    await NotificationService.scheduleLoanReminder(
      id: id,
      borrowerName: borrower.name,
      amount: loan.amount,
      returnDate: _returnDate,
    );

    if (mounted) Navigator.pop(context);
  }
}
