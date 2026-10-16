class LoanPayment {
  final int? id;
  final int loanId;
  final double amount;
  final String paidDate;
  final String? note;

  const LoanPayment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.paidDate,
    this.note,
  });

  factory LoanPayment.fromMap(Map<String, dynamic> m) => LoanPayment(
        id: m['id'] as int?,
        loanId: m['loan_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        paidDate: m['paid_date'] as String,
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'loan_id': loanId,
        'amount': amount,
        'paid_date': paidDate,
        if (note != null) 'note': note,
      };
}
