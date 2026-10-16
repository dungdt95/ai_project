import 'bank.dart';

class BankDeposit {
  final int? id;
  final int bankId;
  final double amount;
  final double? interestRate;
  final String startDate;
  final String dueDate;
  final int? termMonths;
  final String status; // 'active' | 'closed'
  final String? note;
  final String createdAt;
  final String updatedAt;
  Bank? bank;

  BankDeposit({
    this.id,
    required this.bankId,
    required this.amount,
    this.interestRate,
    required this.startDate,
    required this.dueDate,
    this.termMonths,
    this.status = 'active',
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.bank,
  });

  factory BankDeposit.fromMap(Map<String, dynamic> m) => BankDeposit(
        id: m['id'] as int?,
        bankId: m['bank_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        interestRate: m['interest_rate'] != null ? (m['interest_rate'] as num).toDouble() : null,
        startDate: m['start_date'] as String,
        dueDate: m['due_date'] as String,
        termMonths: m['term_months'] as int?,
        status: m['status'] as String? ?? 'active',
        note: m['note'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'bank_id': bankId,
        'amount': amount,
        if (interestRate != null) 'interest_rate': interestRate,
        'start_date': startDate,
        'due_date': dueDate,
        if (termMonths != null) 'term_months': termMonths,
        'status': status,
        if (note != null) 'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  BankDeposit copyWith({String? status}) => BankDeposit(
        id: id, bankId: bankId, amount: amount, interestRate: interestRate,
        startDate: startDate, dueDate: dueDate, termMonths: termMonths,
        status: status ?? this.status, note: note, createdAt: createdAt,
        updatedAt: updatedAt, bank: bank,
      );
}
