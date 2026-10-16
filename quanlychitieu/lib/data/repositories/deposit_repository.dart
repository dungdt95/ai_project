import '../database/app_database.dart';
import '../models/bank_deposit.dart';
import '../models/bank.dart';

class DepositRepository {
  final _db = AppDatabase();

  Future<List<BankDeposit>> getAll({String? status}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT d.*, b.code as bank_code, b.name as bank_name, b.logo as bank_logo
      FROM bank_deposits d
      LEFT JOIN banks b ON d.bank_id = b.id
      ${status != null ? "WHERE d.status = '$status'" : ''}
      ORDER BY d.due_date ASC
    ''');

    return maps.map((m) {
      final dep = BankDeposit.fromMap(m);
      dep.bank = Bank(
        id: m['bank_id'] as int?,
        code: m['bank_code'] as String? ?? '',
        name: m['bank_name'] as String? ?? '',
        logo: m['bank_logo'] as String?,
      );
      return dep;
    }).toList();
  }

  Future<List<BankDeposit>> getUpcoming(int days) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT d.*, b.code as bank_code, b.name as bank_name, b.logo as bank_logo
      FROM bank_deposits d
      LEFT JOIN banks b ON d.bank_id = b.id
      WHERE d.status = 'active'
        AND d.due_date <= date('now', '+$days days')
        AND d.due_date >= date('now')
      ORDER BY d.due_date ASC
    ''');

    return maps.map((m) {
      final dep = BankDeposit.fromMap(m);
      dep.bank = Bank(
        id: m['bank_id'] as int?,
        code: m['bank_code'] as String? ?? '',
        name: m['bank_name'] as String? ?? '',
        logo: m['bank_logo'] as String?,
      );
      return dep;
    }).toList();
  }

  Future<double> getTotalActive() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM bank_deposits WHERE status = 'active'",
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  Future<int> insert(BankDeposit d) async {
    final db = await _db.database;
    return db.insert('bank_deposits', d.toMap());
  }

  Future<void> update(BankDeposit d) async {
    final db = await _db.database;
    await db.update('bank_deposits', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('bank_deposits', where: 'id = ?', whereArgs: [id]);
  }
}
