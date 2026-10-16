import '../../core/db/app_database.dart';
import '../models/invoice_counts.dart';
import '../models/revenue_point.dart';
import '../models/top_item.dart';

class ReportRepository {
  final AppDatabase _appDb = AppDatabase.instance;

  /// Revenue grouped by the day a payment was *confirmed* (paid_at), not
  /// the day the invoice was created — revenue is recognized when money
  /// actually lands, matching how the QR/notification flow confirms it.
  Future<List<RevenuePoint>> getRevenueByDay(
      DateTime start, DateTime end) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT date(paid_at) AS day, SUM(total_amount) AS revenue, COUNT(*) AS cnt
      FROM invoices
      WHERE status = 'paid' AND paid_at BETWEEN ? AND ?
      GROUP BY day
      ORDER BY day ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return rows.map((row) {
      return RevenuePoint(
        day: DateTime.parse(row['day'] as String),
        revenue: (row['revenue'] as int?) ?? 0,
        invoiceCount: (row['cnt'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<List<TopItem>> getTopItems(DateTime start, DateTime end,
      {int limit = 5}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT
        invoice_items.item_name_snapshot AS name,
        SUM(invoice_items.quantity) AS qty,
        SUM(invoice_items.quantity * invoice_items.price_snapshot) AS revenue
      FROM invoice_items
      INNER JOIN invoices ON invoices.id = invoice_items.invoice_id
      WHERE invoices.status = 'paid' AND invoices.paid_at BETWEEN ? AND ?
      GROUP BY invoice_items.item_name_snapshot
      ORDER BY revenue DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return rows.map((row) {
      return TopItem(
        name: row['name'] as String,
        quantity: (row['qty'] as int?) ?? 0,
        revenue: (row['revenue'] as int?) ?? 0,
      );
    }).toList();
  }

  /// Counts invoices created within the range, by their current status —
  /// answers "how many invoices did I create today and what happened to
  /// them", as opposed to revenue which is scoped by payment date.
  Future<InvoiceCounts> getInvoiceCounts(DateTime start, DateTime end) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT status, COUNT(*) AS cnt
      FROM invoices
      WHERE created_at BETWEEN ? AND ?
      GROUP BY status
    ''', [start.toIso8601String(), end.toIso8601String()]);

    var paid = 0, unpaid = 0, cancelled = 0;
    for (final row in rows) {
      final count = (row['cnt'] as int?) ?? 0;
      switch (row['status'] as String) {
        case 'paid':
          paid = count;
          break;
        case 'unpaid':
          unpaid = count;
          break;
        case 'cancelled':
          cancelled = count;
          break;
      }
    }
    return InvoiceCounts(paid: paid, unpaid: unpaid, cancelled: cancelled);
  }
}
