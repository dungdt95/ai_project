import 'package:flutter/foundation.dart';

import '../../data/models/invoice.dart';
import '../../data/models/invoice_item.dart';
import '../../data/repositories/invoice_repository.dart';

class InvoicesController extends ChangeNotifier {
  final InvoiceRepository _repo = InvoiceRepository();

  List<Invoice> _invoices = [];
  String? _statusFilter;
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  String? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _invoices = await _repo.getAll(status: _statusFilter);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setStatusFilter(String? status) async {
    _statusFilter = status;
    await load();
  }

  Future<List<InvoiceItem>> getItems(int invoiceId) {
    return _repo.getItems(invoiceId);
  }

  Future<Invoice> createInvoice(List<InvoiceItem> items) async {
    final total = items.fold<int>(0, (sum, i) => sum + i.subtotal);
    final invoice = await _repo.create(totalAmount: total, items: items);
    await load();
    return invoice;
  }

  Future<void> markPaid(int invoiceId, {String paidMethod = 'cash'}) async {
    await _repo.markPaid(invoiceId, paidMethod: paidMethod);
    await load();
  }

  Future<void> cancel(int invoiceId) async {
    await _repo.cancel(invoiceId);
    await load();
  }
}
