import '../../core/db/app_database.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class InvoiceRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  Future<List<Invoice>> getAll({String? status}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'invoices',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<Invoice?> getById(int id) async {
    final db = await _appDb.database;
    final rows =
        await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Invoice.fromMap(rows.first);
  }

  Future<List<InvoiceItem>> getItems(int invoiceId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return rows.map(InvoiceItem.fromMap).toList();
  }

  /// Creates an invoice and its line items in a single transaction.
  /// The invoice code (e.g. HD000001) is derived from the auto-increment
  /// row id, guaranteeing uniqueness without a separate counter table.
  Future<Invoice> create({
    required int totalAmount,
    required List<InvoiceItem> items,
  }) async {
    final db = await _appDb.database;
    return db.transaction((txn) async {
      final id = await txn.insert('invoices', {
        'code': '',
        'created_at': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'status': Invoice.statusUnpaid,
      });

      final code = 'HD${id.toString().padLeft(6, '0')}';
      await txn.update(
        'invoices',
        {'code': code},
        where: 'id = ?',
        whereArgs: [id],
      );

      for (final item in items) {
        await txn.insert('invoice_items', item.toMap()..['invoice_id'] = id);
      }

      final row =
          (await txn.query('invoices', where: 'id = ?', whereArgs: [id])).first;
      return Invoice.fromMap(row);
    });
  }

  Future<void> markPaid(int invoiceId,
      {String paidMethod = 'cash', int? matchedNotificationId}) async {
    final db = await _appDb.database;
    await db.update(
      'invoices',
      {
        'status': Invoice.statusPaid,
        'paid_at': DateTime.now().toIso8601String(),
        'paid_method': paidMethod,
        if (matchedNotificationId != null)
          'matched_notification_id': matchedNotificationId,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<Invoice?> getUnpaidByCode(String code) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'invoices',
      where: 'code = ? AND status = ?',
      whereArgs: [code, Invoice.statusUnpaid],
      limit: 1,
    );
    return rows.isEmpty ? null : Invoice.fromMap(rows.first);
  }

  Future<List<Invoice>> getUnpaidByAmount(int amount) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'invoices',
      where: 'total_amount = ? AND status = ?',
      whereArgs: [amount, Invoice.statusUnpaid],
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<void> cancel(int invoiceId) async {
    final db = await _appDb.database;
    await db.update(
      'invoices',
      {'status': Invoice.statusCancelled},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
