import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/enums.dart';
import '../../domain/stats/stats_models.dart';
import '../database/app_database.dart';

/// Các truy vấn tổng hợp cho thống kê và quyết toán (PLAN §4.4).
///
/// Tính bằng SQL thay vì tải hết hóa đơn lên Dart rồi cộng: với 1.000 hóa đơn
/// thì chênh lệch là vài chục mili giây so với vài giây (NFR-3).
///
/// Mọi truy vấn ở đây đều loại hóa đơn `deleted_at IS NOT NULL` và hóa đơn
/// nháp, vì nháp chưa phải chi phí thật (SPEC FR-3.10).
class StatsDao {
  const StatsDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const String _liveBill =
      "b.deleted_at IS NULL AND b.status != '$_draft'";

  static const String _draft = 'draft';

  /// Tổng chi phí của từng thành viên (SPEC FR-7.1).
  Future<List<MemberStat>> memberTotals(DateRange range) async {
    final rows = await _db.rawQuery(
      '''
      SELECT m.id            AS member_id,
             m.name          AS member_name,
             m.avatar_color  AS avatar_color,
             SUM(bp.share_amount) AS total_spent,
             COUNT(*)             AS bill_count
      FROM   ${Tables.billParticipants} bp
      JOIN   ${Tables.bills}   b ON b.id = bp.bill_id
      JOIN   ${Tables.members} m ON m.id = bp.member_id
      WHERE  $_liveBill
        AND  b.bill_date BETWEEN ? AND ?
      GROUP  BY m.id
      ORDER  BY total_spent DESC
      ''',
      [range.fromMs, range.toMs],
    );
    return rows.map(MemberStat.fromRow).toList();
  }

  /// Tổng chi từng thành viên, bóc theo danh mục (SPEC FR-7.13).
  ///
  /// Cộng `share_amount` — con số cuối cùng sau phụ phí và làm tròn — nên tổng
  /// các dòng của một người khớp đúng tổng chi của người đó ở bảng xếp hạng.
  /// Gộp theo đơn giá từng món thì không được như vậy: tiền món là phần gốc,
  /// chưa có phụ phí.
  Future<List<MemberCategoryStat>> memberCategoryTotals(DateRange range) async {
    final rows = await _db.rawQuery(
      '''
      SELECT m.id            AS member_id,
             m.name          AS member_name,
             m.avatar_color  AS avatar_color,
             c.id            AS category_id,
             c.name          AS category_name,
             c.icon          AS category_icon,
             SUM(bp.share_amount) AS total,
             COUNT(*)             AS cnt
      FROM   ${Tables.billParticipants} bp
      JOIN   ${Tables.bills}   b ON b.id = bp.bill_id
      JOIN   ${Tables.members} m ON m.id = bp.member_id
      LEFT   JOIN ${Tables.categories} c ON c.id = b.category_id
      WHERE  $_liveBill
        AND  b.bill_date BETWEEN ? AND ?
      GROUP  BY m.id, b.category_id
      HAVING total > 0
      ORDER  BY total DESC
      ''',
      [range.fromMs, range.toMs],
    );
    return rows.map(MemberCategoryStat.fromRow).toList();
  }

  /// Chi phí từng lần theo mỗi hóa đơn của một thành viên (SPEC FR-7.2).
  Future<List<MemberBillEntry>> memberTimeline(
    String memberId, {
    DateRange? range,
    int? limit,
  }) async {
    final hasRange = range != null;
    final rows = await _db.rawQuery(
      '''
      SELECT b.id           AS bill_id,
             b.title        AS title,
             b.bill_date    AS bill_date,
             b.total_amount AS total_amount,
             b.status       AS status,
             bp.share_amount AS share_amount,
             bp.paid_amount  AS paid_amount,
             bp.settled_at   AS settled_at,
             c.name AS category_name,
             c.icon AS category_icon
      FROM   ${Tables.billParticipants} bp
      JOIN   ${Tables.bills} b ON b.id = bp.bill_id
      LEFT   JOIN ${Tables.categories} c ON c.id = b.category_id
      WHERE  bp.member_id = ?
        AND  $_liveBill
        ${hasRange ? 'AND b.bill_date BETWEEN ? AND ?' : ''}
      ORDER  BY b.bill_date DESC, b.created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}
      ''',
      [memberId, if (hasRange) range.fromMs, if (hasRange) range.toMs],
    );
    return rows.map(MemberBillEntry.fromRow).toList();
  }

  /// Số dư ròng của mọi thành viên (SPEC FR-6.4).
  ///
  /// Gộp bốn nguồn: đã ứng trả, phải chịu, đã chuyển đi, đã nhận về. Tổng
  /// `balance` của mọi người phải bằng 0 — đây là bất biến dùng để kiểm thử.
  Future<List<MemberBalance>> balances() async {
    final rows = await _db.rawQuery('''
      WITH owed AS (
        SELECT bp.member_id AS mid, SUM(bp.share_amount) AS s
        FROM ${Tables.billParticipants} bp
        JOIN ${Tables.bills} b ON b.id = bp.bill_id
        WHERE $_liveBill
        GROUP BY 1
      ),
      advanced AS (
        SELECT pay.member_id AS mid, SUM(pay.paid_amount) AS s
        FROM ${Tables.billPayers} pay
        JOIN ${Tables.bills} b ON b.id = pay.bill_id
        WHERE $_liveBill
        GROUP BY 1
      ),
      sent AS (
        SELECT from_member_id AS mid, SUM(amount) AS s
        FROM ${Tables.payments} GROUP BY 1
      ),
      recv AS (
        SELECT to_member_id AS mid, SUM(amount) AS s
        FROM ${Tables.payments} GROUP BY 1
      )
      SELECT m.id           AS member_id,
             m.name         AS member_name,
             m.avatar_color AS avatar_color,
             COALESCE(advanced.s, 0) AS advanced,
             COALESCE(owed.s, 0)     AS owed,
             COALESCE(sent.s, 0)     AS sent,
             COALESCE(recv.s, 0)     AS received
      FROM   ${Tables.members} m
      LEFT   JOIN owed     ON owed.mid     = m.id
      LEFT   JOIN advanced ON advanced.mid = m.id
      LEFT   JOIN sent     ON sent.mid     = m.id
      LEFT   JOIN recv     ON recv.mid     = m.id
      WHERE  m.deleted_at IS NULL
      ORDER  BY (COALESCE(advanced.s,0) - COALESCE(owed.s,0)
               + COALESCE(sent.s,0)     - COALESCE(recv.s,0)) DESC
      ''');
    return rows.map(MemberBalance.fromRow).toList();
  }

  /// Tổng chi theo tháng, mới nhất trước (SPEC FR-7.6).
  /// Tổng chi theo tuần, tuần tính từ thứ Hai.
  ///
  /// `strftime('%w')` trả 0 cho Chủ nhật tới 6 cho thứ Bảy, nên `(w + 6) % 7`
  /// ra số ngày đã trôi qua kể từ thứ Hai — lùi lại chừng đó ngày là về đầu
  /// tuần. Không dùng `%W` (số thứ tự tuần trong năm) vì từ con số đó không
  /// dựng lại được khoảng ngày để hiển thị.
  Future<List<WeeklyStat>> weeklyTotals({int weeks = 12}) async {
    const local = "b.bill_date / 1000, 'unixepoch', 'localtime'";

    final rows = await _db.rawQuery(
      '''
      SELECT date($local,
                  '-' || ((strftime('%w', $local) + 6) % 7) || ' days') AS wk,
             SUM(b.total_amount) AS total,
             COUNT(*)            AS cnt
      FROM   ${Tables.bills} b
      WHERE  $_liveBill
      GROUP  BY wk
      ORDER  BY wk DESC
      LIMIT  ?
      ''',
      [weeks],
    );
    return rows.map(WeeklyStat.fromRow).toList();
  }

  Future<List<MonthlyStat>> monthlyTotals({int months = 12}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT strftime('%Y-%m', b.bill_date / 1000, 'unixepoch', 'localtime') AS ym,
             SUM(b.total_amount) AS total,
             COUNT(*)            AS cnt
      FROM   ${Tables.bills} b
      WHERE  $_liveBill
      GROUP  BY ym
      ORDER  BY ym DESC
      LIMIT  ?
      ''',
      [months],
    );
    return rows.map(MonthlyStat.fromRow).toList();
  }

  /// Tổng chi theo danh mục (SPEC FR-7.7).
  Future<List<CategoryStat>> categoryTotals(DateRange range) async {
    final rows = await _db.rawQuery(
      '''
      SELECT c.id    AS category_id,
             c.name  AS category_name,
             c.icon  AS category_icon,
             c.color AS category_color,
             SUM(b.total_amount) AS total,
             COUNT(*)            AS cnt
      FROM   ${Tables.bills} b
      LEFT   JOIN ${Tables.categories} c ON c.id = b.category_id
      WHERE  $_liveBill
        AND  b.bill_date BETWEEN ? AND ?
      GROUP  BY c.id
      ORDER  BY total DESC
      ''',
      [range.fromMs, range.toMs],
    );
    return rows.map(CategoryStat.fromRow).toList();
  }

  /// Chỉ số cho Dashboard (SPEC FR-7.8).
  ///
  /// [selfMemberId] là bản ghi "Tôi"; `null` khi DB chưa có bản ghi nào, lúc
  /// đó trả về giá trị rỗng thay vì lỗi.
  Future<DashboardSummary> dashboard(String? selfMemberId) async {
    if (selfMemberId == null) return DashboardSummary.empty;

    final month = DateRange.thisMonth();

    final monthRows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(bp.share_amount), 0) AS total,
             COUNT(*)                          AS cnt
      FROM   ${Tables.billParticipants} bp
      JOIN   ${Tables.bills} b ON b.id = bp.bill_id
      WHERE  bp.member_id = ?
        AND  $_liveBill
        AND  b.bill_date BETWEEN ? AND ?
      ''',
      [selfMemberId, month.fromMs, month.toMs],
    );

    // Số dư ròng của "Tôi" đã gói đủ cả hai chiều: dương nghĩa là nhóm còn nợ
    // mình, âm nghĩa là mình còn nợ nhóm. Chỉ một trong hai khác 0.
    final allBalances = await balances();
    final selfBalance = allBalances
        .where((b) => b.memberId == selfMemberId)
        .map((b) => b.balance)
        .firstOrNull;
    final owedToMe = (selfBalance ?? 0) > 0 ? selfBalance! : 0;
    final iOwe = (selfBalance ?? 0) < 0 ? -selfBalance! : 0;

    final unsettledRows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM ${Tables.bills} b
      WHERE b.deleted_at IS NULL AND b.status IN (?, ?)
      ''',
      [BillStatus.unpaid.dbValue, BillStatus.partial.dbValue],
    );

    return DashboardSummary(
      monthTotal: (monthRows.first['total'] as int?) ?? 0,
      monthBillCount: (monthRows.first['cnt'] as int?) ?? 0,
      owedToMe: owedToMe,
      iOwe: iOwe,
      unsettledBillCount: (unsettledRows.first['cnt'] as int?) ?? 0,
    );
  }

  /// Tổng chi của một nhóm trong khoảng thời gian (SPEC FR-7.10).
  Future<int> groupTotal(String groupId, DateRange range) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(b.total_amount), 0) AS total
      FROM   ${Tables.bills} b
      WHERE  $_liveBill AND b.group_id = ?
        AND  b.bill_date BETWEEN ? AND ?
      ''',
      [groupId, range.fromMs, range.toMs],
    );
    return (rows.first['total'] as int?) ?? 0;
  }
}
