import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/notification/notification_access.dart';
import '../../core/qr/vietqr_builder.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import '../invoices/invoices_controller.dart';
import '../settings/bank_accounts_controller.dart';
import '../settings/settings_screen.dart';

class PaymentQrScreen extends StatefulWidget {
  final int invoiceId;

  const PaymentQrScreen({super.key, required this.invoiceId});

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  final _invoiceRepo = InvoiceRepository();
  Invoice? _invoice;
  Timer? _pollTimer;
  bool _notificationAccessGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankAccountsController>().load();
    });
    NotificationAccess.isGranted().then((granted) {
      if (mounted) setState(() => _notificationAccessGranted = granted);
    });
    _loadInvoice();
    // The real confirmation can land from a separate headless background
    // isolate (the NotificationListenerService), which has no way to push
    // an update into this engine's Provider tree — so this screen polls
    // the DB directly while waiting, instead of trusting cached state.
    _pollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _loadInvoice());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    final invoice = await _invoiceRepo.getById(widget.invoiceId);
    if (!mounted) return;
    final wasUnpaid = _invoice?.status != Invoice.statusPaid;
    setState(() => _invoice = invoice);
    if (wasUnpaid && invoice?.status == Invoice.statusPaid) {
      _pollTimer?.cancel();
      if (mounted) context.read<InvoicesController>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankController = context.watch<BankAccountsController>();
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(title: const Text('QR chuyển tiền')),
      body: invoice == null
          ? const Center(child: CircularProgressIndicator())
          : bankController.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context, invoice, bankController),
    );
  }

  Widget _buildBody(BuildContext context, Invoice invoice,
      BankAccountsController bankController) {
    if (invoice.status == Invoice.statusPaid) {
      return _buildPaidState(invoice);
    }

    final defaultAccount = bankController.accounts.where((a) => a.isDefault);
    if (defaultAccount.isEmpty) {
      return _buildNoAccountState(context);
    }

    final account = defaultAccount.first;
    final qrData = VietQrBuilder.build(
      bankBin: account.bankBin,
      accountNumber: account.accountNumber,
      amount: invoice.totalAmount,
      addInfo: invoice.code,
      merchantName: account.accountName,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_notificationAccessGranted) _buildPermissionWarning(invoice),
            Text(invoice.code,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              formatVnd(invoice.totalAmount),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: QrImageView(data: qrData, size: 260, gapless: true),
            ),
            const SizedBox(height: 24),
            Text('${account.bankName} • ${account.accountNumber}'),
            Text(account.accountName),
            const SizedBox(height: 8),
            Text(
              'Nội dung chuyển khoản: ${invoice.code}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Đang chờ thanh toán...'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng giữ nguyên nội dung chuyển khoản để hệ thống tự xác nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            if (!_notificationAccessGranted) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _confirmManually(invoice),
                child: const Text('Đã nhận tiền (xác nhận thủ công)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionWarning(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chưa cấp quyền đọc thông báo — app sẽ KHÔNG tự xác nhận thanh toán. '
              'Hãy bấm "Đã nhận tiền" sau khi khách chuyển khoản thành công.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmManually(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Text(
            'Xác nhận đã nhận ${formatVnd(invoice.totalAmount)} cho hóa đơn ${invoice.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context
        .read<InvoicesController>()
        .markPaid(invoice.id!, paidMethod: 'cash');
    await _loadInvoice();
  }

  Widget _buildPaidState(Invoice invoice) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 96),
          const SizedBox(height: 16),
          Text(
            'Đã thanh toán ${formatVnd(invoice.totalAmount)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(invoice.code),
        ],
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chưa có tài khoản ngân hàng mặc định.\nVui lòng thêm tài khoản trong Cài đặt trước khi tạo QR.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Đi tới Cài đặt'),
            ),
          ],
        ),
      ),
    );
  }
}
