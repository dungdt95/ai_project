import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../domain/models/payment.dart';
import '../database/app_database.dart';

/// Truy cập bảng `payments` — các lần chuyển tiền thực tế (SPEC FR-6.6).
class PaymentDao {
  const PaymentDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<Payment>> getAll({int? limit}) async {
    final rows = await _db.query(
      Tables.payments,
      orderBy: 'paid_at DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// Mọi giao dịch có liên quan tới một thành viên, ở cả hai chiều.
  Future<List<Payment>> getByMember(String memberId) async {
    final rows = await _db.query(
      Tables.payments,
      where: 'from_member_id = ? OR to_member_id = ?',
      whereArgs: [memberId, memberId],
      orderBy: 'paid_at DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getByBill(String billId) async {
    final rows = await _db.query(
      Tables.payments,
      where: 'bill_id = ?',
      whereArgs: [billId],
      orderBy: 'paid_at DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<void> insert(Payment payment) async {
    await _db.insert(Tables.payments, payment.toMap());
  }

  Future<void> update(Payment payment) async {
    await _db.update(
      Tables.payments,
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  /// Xóa cứng: giao dịch chuyển tiền ghi sai thì phải mất hẳn, nếu không số dư
  /// ròng sẽ lệch mãi (SPEC FR-6.4).
  Future<void> delete(String id) async {
    await _db.delete(Tables.payments, where: 'id = ?', whereArgs: [id]);
  }

  /// Tổng tiền đã chuyển từ một người sang một người khác.
  Future<int> totalBetween(String fromMemberId, String toMemberId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total FROM ${Tables.payments}
      WHERE from_member_id = ? AND to_member_id = ?
      ''',
      [fromMemberId, toMemberId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }
}
