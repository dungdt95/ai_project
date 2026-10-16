import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_item.dart';
import '../payment_qr/payment_qr_screen.dart';
import 'invoices_controller.dart';
import 'widgets/status_badge.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InvoicesController>();
    final invoice = controller.invoices.where((i) => i.id == widget.invoiceId);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hóa đơn')),
      body: invoice.isEmpty
          ? FutureBuilder<List<InvoiceItem>>(
              future: controller.getItems(widget.invoiceId),
              builder: (context, snapshot) => _buildLoadingOrEmpty(snapshot),
            )
          : _InvoiceBody(invoice: invoice.first, controller: controller),
    );
  }

  Widget _buildLoadingOrEmpty(AsyncSnapshot<List<InvoiceItem>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(child: Text('Không tìm thấy hóa đơn.'));
  }
}

class _InvoiceBody extends StatelessWidget {
  final Invoice invoice;
  final InvoicesController controller;

  const _InvoiceBody({required this.invoice, required this.controller});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvoiceItem>>(
      future: controller.getItems(invoice.id!),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.code,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(formatDateTime(invoice.createdAt)),
                    ],
                  ),
                  StatusBadge(status: invoice.status),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final line = items[index];
                        return ListTile(
                          title: Text(line.itemNameSnapshot),
                          subtitle: Text(
                              '${formatVnd(line.priceSnapshot)} x ${line.quantity}'),
                          trailing: Text(formatVnd(line.subtotal)),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    formatVnd(invoice.totalAmount),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            if (invoice.status == Invoice.statusUnpaid)
              _buildUnpaidActions(context),
            if (invoice.status == Invoice.statusPaid) _buildPaidInfo(context),
          ],
        );
      },
    );
  }

  Widget _buildUnpaidActions(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PaymentQrScreen(invoiceId: invoice.id!)),
                ),
                icon: const Icon(Icons.qr_code),
                label: const Text('Tạo QR chuyển khoản'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmCancel(context),
                    child: const Text('Hủy hóa đơn'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmMarkPaid(context),
                    child: const Text('Đã nhận tiền'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        'Đã thanh toán lúc ${formatDateTime(invoice.paidAt!)} (${invoice.paidMethod ?? 'cash'})',
        style: const TextStyle(color: Colors.green),
      ),
    );
  }

  Future<void> _confirmMarkPaid(BuildContext context) async {
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
    if (confirmed == true) {
      await controller.markPaid(invoice.id!, paidMethod: 'cash');
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy hóa đơn'),
        content: Text(
            'Hủy hóa đơn ${invoice.code}? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hủy hóa đơn'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.cancel(invoice.id!);
    }
  }
}
