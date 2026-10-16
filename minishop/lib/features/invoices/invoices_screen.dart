import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/invoice.dart';
import 'invoice_detail_screen.dart';
import 'invoices_controller.dart';
import 'new_invoice_screen.dart';
import 'widgets/status_badge.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  static const _filters = <String?, String>{
    null: 'Tất cả',
    Invoice.statusUnpaid: 'Chưa TT',
    Invoice.statusPaid: 'Đã TT',
    Invoice.statusCancelled: 'Đã hủy',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoicesController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InvoicesController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _filters.entries.map((entry) {
                final selected = controller.statusFilter == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => controller.setStatusFilter(entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: controller.load,
                    child: controller.invoices.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 200),
                              Center(
                                  child: Text(
                                      'Chưa có hóa đơn nào. Bấm + để tạo.')),
                            ],
                          )
                        : ListView.builder(
                            itemCount: controller.invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = controller.invoices[index];
                              return ListTile(
                                title: Text(invoice.code),
                                subtitle:
                                    Text(formatDateTime(invoice.createdAt)),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(formatVnd(invoice.totalAmount)),
                                    const SizedBox(height: 4),
                                    StatusBadge(status: invoice.status),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(
                                        invoiceId: invoice.id!),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewInvoiceScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
