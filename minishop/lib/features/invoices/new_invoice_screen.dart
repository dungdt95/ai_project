import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/invoice_item.dart';
import '../../data/models/item.dart';
import '../items/items_controller.dart';
import 'invoice_detail_screen.dart';
import 'invoices_controller.dart';

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final Map<int, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemsController>().load();
    });
  }

  int get _totalAmount {
    final items = context.read<ItemsController>().items;
    var total = 0;
    for (final item in items) {
      final qty = _quantities[item.id] ?? 0;
      total += item.price * qty;
    }
    return total;
  }

  void _changeQuantity(Item item, int delta) {
    setState(() {
      final current = _quantities[item.id!] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _quantities.remove(item.id);
      } else {
        _quantities[item.id!] = next;
      }
    });
  }

  Future<void> _submit() async {
    final itemsController = context.read<ItemsController>();
    final invoicesController = context.read<InvoicesController>();
    final lines = <InvoiceItem>[];
    for (final item in itemsController.items) {
      final qty = _quantities[item.id] ?? 0;
      if (qty <= 0) continue;
      lines.add(InvoiceItem(
        itemId: item.id,
        itemNameSnapshot: item.name,
        priceSnapshot: item.price,
        quantity: qty,
      ));
    }
    if (lines.isEmpty) return;

    final invoice = await invoicesController.createInvoice(lines);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsController = context.watch<ItemsController>();
    final activeItems = itemsController.items.where((i) => i.isActive).toList();
    final hasSelection = _quantities.values.any((q) => q > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hóa đơn')),
      body: itemsController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeItems.isEmpty
              ? const Center(child: Text('Chưa có mặt hàng đang bán nào.'))
              : ListView.builder(
                  itemCount: activeItems.length,
                  itemBuilder: (context, index) {
                    final item = activeItems[index];
                    final qty = _quantities[item.id] ?? 0;
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('${formatVnd(item.price)} / ${item.unit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0
                                ? () => _changeQuantity(item, -1)
                                : null,
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _changeQuantity(item, 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng: ${formatVnd(_totalAmount)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton(
                onPressed: hasSelection ? _submit : null,
                child: const Text('Tạo hóa đơn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
