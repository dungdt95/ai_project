import '../database/app_database.dart';
import '../models/loan.dart';
import '../models/loan_payment.dart';
import '../models/borrower.dart';

class LoanRepository {
  final _db = AppDatabase();

  Future<List<Loan>> getAll({int? borrowerId}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT l.*, b.name as borrower_name, b.phone as borrower_phone
      FROM loans l
      LEFT JOIN borrowers b ON l.borrower_id = b.id
      ${borrowerId != null ? 'WHERE l.borrower_id = $borrowerId' : ''}
      ORDER BY l.expected_return_date ASC
    ''');

    final loans = <Loan>[];
    for (final m in maps) {
      final loan = Loan.fromMap(m);
      loan.borrower = Borrower(
        id: m['borrower_id'] as int?,
        name: m['borrower_name'] as String? ?? '',
        phone: m['borrower_phone'] as String?,
      );
      loan.payments = await getPayments(loan.id!);
      loans.add(loan);
    }
    return loans;
  }

  Future<List<LoanPayment>> getPayments(int loanId) async {
    final db = await _db.database;
    final maps = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'paid_date DESC',
    );
    return maps.map(LoanPayment.fromMap).toList();
  }

  Future<int> insert(Loan l) async {
    final db = await _db.database;
    return db.insert('loans', l.toMap());
  }

  Future<void> update(Loan l) async {
    final db = await _db.database;
    await db.update('loans', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
  }

  Future<void> updateStatus(int id, String status) async {
    final db = await _db.database;
    await db.update('loans', {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertPayment(LoanPayment p) async {
    final db = await _db.database;
    final paymentId = await db.insert('loan_payments', p.toMap());
    await _recalcStatus(p.loanId);
    return paymentId;
  }

  Future<void> deletePayment(int paymentId, int loanId) async {
    final db = await _db.database;
    await db.delete('loan_payments', where: 'id = ?', whereArgs: [paymentId]);
    await _recalcStatus(loanId);
  }

  Future<void> _recalcStatus(int loanId) async {
    final db = await _db.database;
    final loanMaps = await db.query('loans', where: 'id = ?', whereArgs: [loanId]);
    if (loanMaps.isEmpty) return;
    final loan = Loan.fromMap(loanMaps.first);

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM loan_payments WHERE loan_id = ?',
      [loanId],
    );
    final totalPaid = (result.first['total'] as num? ?? 0).toDouble();

    String status;
    if (totalPaid >= loan.amount) {
      status = 'paid';
    } else if (totalPaid > 0) {
      status = 'partial';
    } else {
      final today = DateTime.now();
      final due = DateTime.parse(loan.expectedReturnDate);
      status = today.isAfter(due) ? 'overdue' : 'unpaid';
    }
    await db.update('loans', {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [loanId]);
  }

  Future<void> checkAndMarkOverdue() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await db.rawUpdate('''
      UPDATE loans
      SET status = 'overdue', updated_at = ?
      WHERE status = 'unpaid' AND expected_return_date < ?
    ''', [DateTime.now().toIso8601String(), today]);
  }

  Future<List<Map<String, dynamic>>> getBorrowerSummary() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT b.id, b.name, b.phone,
             COUNT(l.id) as total_loans,
             COALESCE(SUM(l.amount), 0) as total_lent,
             COALESCE(SUM(p_sum.paid), 0) as total_paid,
             COALESCE(SUM(l.amount), 0) - COALESCE(SUM(p_sum.paid), 0) as outstanding,
             SUM(CASE WHEN l.status != 'paid' THEN 1 ELSE 0 END) as open_loans
      FROM borrowers b
      LEFT JOIN loans l ON b.id = l.borrower_id
      LEFT JOIN (
        SELECT loan_id, SUM(amount) as paid FROM loan_payments GROUP BY loan_id
      ) p_sum ON l.id = p_sum.loan_id
      GROUP BY b.id
      HAVING total_loans > 0
      ORDER BY outstanding DESC
    ''');
  }

  Future<double> getTotalOutstanding() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT SUM(l.amount) - COALESCE(SUM(p.amount), 0) as outstanding
      FROM loans l
      LEFT JOIN loan_payments p ON l.id = p.loan_id
      WHERE l.status != 'paid'
    ''');
    return (result.first['outstanding'] as num? ?? 0).toDouble();
  }
}
