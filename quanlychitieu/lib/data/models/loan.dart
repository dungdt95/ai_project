import 'borrower.dart';
import 'loan_payment.dart';

class Loan {
  final int? id;
  final int borrowerId;
  final double amount;
  final String loanDate;
  final String expectedReturnDate;
  final double interestRate;
  final String status; // 'unpaid'|'partial'|'paid'|'overdue'
  final String? note;
  final String createdAt;
  final String updatedAt;
  Borrower? borrower;
  List<LoanPayment> payments;

  Loan({
    this.id,
    required this.borrowerId,
    required this.amount,
    required this.loanDate,
    required this.expectedReturnDate,
    this.interestRate = 0,
    this.status = 'unpaid',
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.borrower,
    this.payments = const [],
  });

  double get totalPaid => payments.fold(0, (s, p) => s + p.amount);
  double get remaining => amount - totalPaid;

  factory Loan.fromMap(Map<String, dynamic> m) => Loan(
        id: m['id'] as int?,
        borrowerId: m['borrower_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        loanDate: m['loan_date'] as String,
        expectedReturnDate: m['expected_return_date'] as String,
        interestRate: (m['interest_rate'] as num? ?? 0).toDouble(),
        status: m['status'] as String? ?? 'unpaid',
        note: m['note'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'borrower_id': borrowerId,
        'amount': amount,
        'loan_date': loanDate,
        'expected_return_date': expectedReturnDate,
        'interest_rate': interestRate,
        'status': status,
        if (note != null) 'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
