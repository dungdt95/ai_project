import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../domain/models/payment.dart';
import '../database/app_database.dart';
import 'bill_dao.dart';

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

  /// Ghi nhận chuyển tiền và đồng bộ sang từng hóa đơn, trong một giao dịch.
  ///
  /// Nếu sau lần chuyển này người chuyển không còn nợ ròng (số dư >= 0), mọi
  /// phần chưa trả của họ ở các hóa đơn đang hiệu lực (không nháp, không xóa,
  /// họ không phải người ứng tiền) được đánh dấu đã trả. Số dư quyết toán tính
  /// từ `share_amount` và `payments`, không đọc `paid_amount`, nên việc đánh
  /// dấu này không làm số dư bị tính hai lần.
  ///
  /// Trả về số dòng hóa đơn đã được đánh dấu.
  Future<int> insertAndSync(Payment payment) =>
      _database.transaction((txn) async {
        await txn.insert(Tables.payments, payment.toMap());
        if (await _balanceOf(txn, payment.fromMemberId) < 0) return 0;
        return _markPaid(txn, payment);
      });

  /// Xóa ghi nhận và hoàn tác các dấu "đã trả" do quyết toán của người chuyển
  /// đặt ra (không đụng tới dấu do người dùng tự đặt).
  Future<void> deleteAndRevert(String id) => _database.transaction((txn) async {
    final rows = await txn.query(
      Tables.payments,
      columns: ['from_member_id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    await txn.delete(Tables.payments, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    // Người chuyển không còn được coi là đã quyết toán đủ: hoàn tác mọi dấu
    // do các lần chuyển của họ đặt ra (kể cả chính lần vừa xóa).
    await _revert(txn, rows.first['from_member_id']! as String, id);
  });

  static const String _live = "b.deleted_at IS NULL AND b.status != 'draft'";

  static Future<int> _balanceOf(Transaction txn, String memberId) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        (SELECT COALESCE(SUM(pay.paid_amount), 0)
           FROM ${Tables.billPayers} pay
           JOIN ${Tables.bills} b ON b.id = pay.bill_id
          WHERE pay.member_id = ?1 AND $_live)
      - (SELECT COALESCE(SUM(bp.share_amount), 0)
           FROM ${Tables.billParticipants} bp
           JOIN ${Tables.bills} b ON b.id = bp.bill_id
          WHERE bp.member_id = ?1 AND $_live)
      + (SELECT COALESCE(SUM(amount), 0) FROM ${Tables.payments}
          WHERE from_member_id = ?1)
      - (SELECT COALESCE(SUM(amount), 0) FROM ${Tables.payments}
          WHERE to_member_id = ?1) AS balance
      ''',
      [memberId],
    );
    return (rows.first['balance'] as int?) ?? 0;
  }

  static Future<int> _markPaid(Transaction txn, Payment payment) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await txn.rawQuery(
      '''
      SELECT bp.id, bp.bill_id, bp.paid_amount, bp.share_amount
      FROM ${Tables.billParticipants} bp
      JOIN ${Tables.bills} b ON b.id = bp.bill_id
      WHERE bp.member_id = ? AND $_live
        AND bp.paid_amount < bp.share_amount
        AND NOT EXISTS (
          SELECT 1 FROM ${Tables.billPayers} pay
          WHERE pay.bill_id = bp.bill_id AND pay.member_id = bp.member_id)
      ''',
      [payment.fromMemberId],
    );

    final billIds = <String>{};
    for (final row in rows) {
      await txn.update(
        Tables.billParticipants,
        {
          'paid_amount': row['share_amount'],
          'settled_at': now,
          'settled_by_payment_id': payment.id,
          'settle_prev_paid': row['paid_amount'],
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      billIds.add(row['bill_id']! as String);
    }
    for (final billId in billIds) {
      await BillDao.refreshStatus(txn, billId, now);
    }
    return rows.length;
  }

  static Future<void> _revert(
    Transaction txn,
    String fromMemberId,
    String deletedPaymentId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await txn.rawQuery(
      '''
      SELECT id, bill_id, settle_prev_paid, share_amount
      FROM ${Tables.billParticipants}
      WHERE settled_by_payment_id = ?2
         OR settled_by_payment_id IN (
              SELECT id FROM ${Tables.payments} WHERE from_member_id = ?1)
      ''',
      [fromMemberId, deletedPaymentId],
    );

    final billIds = <String>{};
    for (final row in rows) {
      final prev = row['settle_prev_paid']! as int;
      await txn.update(
        Tables.billParticipants,
        {
          'paid_amount': prev,
          'settled_at': prev >= (row['share_amount']! as int) ? now : null,
          'settled_by_payment_id': null,
          'settle_prev_paid': 0,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      billIds.add(row['bill_id']! as String);
    }
    for (final billId in billIds) {
      await BillDao.refreshStatus(txn, billId, now);
    }
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
