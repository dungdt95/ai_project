import '../models/category.dart';

class Transaction {
  final int? id;
  final String type; // 'income' | 'expense'
  final double amount;
  final int categoryId;
  final String date;
  final String? note;
  final String? paymentMethod;
  final String createdAt;
  final String updatedAt;
  Category? category;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as int?,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int,
        date: m['date'] as String,
        note: m['note'] as String?,
        paymentMethod: m['payment_method'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'date': date,
        if (note != null) 'note': note,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
