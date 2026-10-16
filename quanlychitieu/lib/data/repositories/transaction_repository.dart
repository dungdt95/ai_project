import '../database/app_database.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class TransactionRepository {
  final _db = AppDatabase();

  Future<List<Transaction>> getAll({
    String? type,
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (type != null) { conditions.add('t.type = ?'); args.add(type); }
    if (startDate != null) { conditions.add('t.date >= ?'); args.add(startDate); }
    if (endDate != null) { conditions.add('t.date <= ?'); args.add(endDate); }
    if (categoryId != null) { conditions.add('t.category_id = ?'); args.add(categoryId); }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await db.rawQuery('''
      SELECT t.*, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      $where
      ORDER BY t.date DESC, t.created_at DESC
    ''', args);

    return maps.map((m) {
      final tx = Transaction.fromMap(m);
      tx.category = Category(
        id: m['category_id'] as int?,
        name: m['cat_name'] as String? ?? '',
        type: tx.type,
        icon: m['cat_icon'] as String? ?? 'category',
        color: m['cat_color'] as String? ?? '#9E9E9E',
      );
      return tx;
    }).toList();
  }

  Future<int> insert(Transaction t) async {
    final db = await _db.database;
    return db.insert('transactions', t.toMap());
  }

  Future<void> update(Transaction t) async {
    final db = await _db.database;
    await db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getSummary(String startDate, String endDate) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT type, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ?
      GROUP BY type
    ''', [startDate, endDate]);

    // Tổng chi tiêu loại tín dụng (tách riêng, không tính vào số dư tiền mặt)
    final creditResult = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' AND payment_method = 'credit'
        AND date >= ? AND date <= ?
    ''', [startDate, endDate]);

    double income = 0, expense = 0;
    for (final r in result) {
      if (r['type'] == 'income') income = (r['total'] as num).toDouble();
      if (r['type'] == 'expense') expense = (r['total'] as num).toDouble();
    }
    final credit = (creditResult.first['total'] as num?)?.toDouble() ?? 0;
    return {'income': income, 'expense': expense, 'credit': credit};
  }

  Future<List<Map<String, dynamic>>> getCategoryTotals(String type, String startDate, String endDate) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT c.name, c.color, c.icon, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = ? AND t.date >= ? AND t.date <= ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', [type, startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals(int months) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT strftime('%Y-%m', date) as month,
             SUM(CASE WHEN type='income' THEN amount ELSE 0 END) as income,
             SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE date >= date('now', '-${months - 1} months', 'start of month')
      GROUP BY month
      ORDER BY month ASC
    ''');
  }
}
