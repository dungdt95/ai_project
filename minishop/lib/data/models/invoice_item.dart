class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int? itemId;
  final String itemNameSnapshot;
  final int priceSnapshot;
  final int quantity;

  const InvoiceItem({
    this.id,
    this.invoiceId,
    this.itemId,
    required this.itemNameSnapshot,
    required this.priceSnapshot,
    required this.quantity,
  });

  int get subtotal => priceSnapshot * quantity;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'item_id': itemId,
      'item_name_snapshot': itemNameSnapshot,
      'price_snapshot': priceSnapshot,
      'quantity': quantity,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int?,
      itemId: map['item_id'] as int?,
      itemNameSnapshot: map['item_name_snapshot'] as String,
      priceSnapshot: map['price_snapshot'] as int,
      quantity: map['quantity'] as int,
    );
  }
}
