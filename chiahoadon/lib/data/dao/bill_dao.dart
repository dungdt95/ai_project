import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/db_constants.dart';
import '../../core/utils/vn_text.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/bill_filter.dart';
import '../../domain/models/bill_item.dart';
import '../../domain/models/bill_participant.dart';
import '../../domain/models/enums.dart';
import '../database/app_database.dart';

/// Truy cập hóa đơn và các bảng con của nó (SPEC FR-3).
class BillDao {
  const BillDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Ghi hóa đơn cùng toàn bộ bảng con trong **một giao dịch**.
  ///
  /// Đây là điểm quan trọng nhất của DAO này: nếu `bills` ghi xong mà
  /// `bill_participants` thất bại, tổng các phần sẽ không còn khớp tổng hóa
  /// đơn và dữ liệu rơi vào trạng thái không thể tin được (SPEC FR-4).
  ///
  /// Dùng chung cho thêm mới và cập nhật: các bảng con bị xóa rồi chèn lại,
  /// vì sửa hóa đơn luôn kéo theo tính lại toàn bộ phần chia (SPEC FR-3.13).
  Future<void> save(Bill bill) async {
    await _database.transaction((txn) async {
      await txn.insert(
        Tables.bills,
        {
          ...bill.toMap(),
          // Chỉ mục tìm kiếm, sinh từ tên mỗi lần ghi. Để ở đây thay vì trong
          // model `Bill` vì nó là chi tiết của tầng lưu trữ, không phải dữ
          // liệu nghiệp vụ (SPEC FR-3.12).
          'title_norm': VnText.normalize(bill.title),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // bill_items xóa trước: bill_item_participants trỏ vào nó và sẽ bị
      // ON DELETE CASCADE dọn theo.
      await txn.delete(
        Tables.billItems,
        where: 'bill_id = ?',
        whereArgs: [bill.id],
      );
      await txn.delete(
        Tables.billParticipants,
        where: 'bill_id = ?',
        whereArgs: [bill.id],
      );
      await txn.delete(
        Tables.billPayers,
        where: 'bill_id = ?',
        whereArgs: [bill.id],
      );

      for (final payer in bill.payers) {
        await txn.insert(Tables.billPayers, payer.toMap(bill.id));
      }
      for (final participant in bill.participants) {
        await txn.insert(
          Tables.billParticipants,
          participant.toMap(bill.id),
        );
      }
      for (final item in bill.items) {
        await txn.insert(Tables.billItems, item.toMap(bill.id));
        for (final itemParticipant in item.participants) {
          await txn.insert(
            Tables.billItemParticipants,
            itemParticipant.toMap(item.id),
          );
        }
      }
    });
  }

  /// Hóa đơn kèm đầy đủ người tham gia, người ứng tiền và món.
  Future<Bill?> getById(String id) async {
    final rows = await _db.query(
      Tables.bills,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final participants = await _participantsOf([id]);
    final payers = await _payersOf([id]);
    final items = await _itemsOf([id]);

    return Bill.fromMap(
      rows.first,
      participants: participants[id] ?? const [],
      payers: payers[id] ?? const [],
      items: items[id] ?? const [],
    );
  }

  /// Một trang danh sách hóa đơn theo [filter].
  ///
  /// Nạp người tham gia và người ứng tiền cho cả trang bằng hai truy vấn
  /// `IN (...)`, thay vì một truy vấn cho mỗi hóa đơn — danh sách 50 dòng khi
  /// đó tốn 3 truy vấn chứ không phải 101 (NFR-3). Món không nạp vì danh sách
  /// không hiển thị tới mức đó.
  Future<List<Bill>> getPage(
    BillFilter filter, {
    int limit = AppConstants.billPageSize,
    int offset = 0,
  }) async {
    final (where, args) = _buildWhere(filter);

    final rows = await _db.query(
      Tables.bills,
      where: where,
      whereArgs: args,
      orderBy: 'bill_date DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id']! as String).toList();
    final participants = await _participantsOf(ids);
    final payers = await _payersOf(ids);

    return rows.map((row) {
      final id = row['id']! as String;
      return Bill.fromMap(
        row,
        participants: participants[id] ?? const [],
        payers: payers[id] ?? const [],
      );
    }).toList();
  }

  Future<int> count(BillFilter filter) async {
    final (where, args) = _buildWhere(filter);
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.bills} WHERE $where',
      args,
    );
    return result.first['cnt']! as int;
  }

  /// Soft delete, cho phép hoàn tác trong 5 giây (SPEC FR-3.14).
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      Tables.bills,
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restore(String id) async {
    await _db.update(
      Tables.bills,
      {
        'deleted_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cập nhật số tiền một người đã trả lại cho người ứng (SPEC FR-6.1).
  ///
  /// Cập nhật luôn `bills.status` trong cùng giao dịch, để danh sách hóa đơn
  /// không phải tính lại trạng thái từ các bảng con mỗi lần vẽ.
  Future<void> updateParticipantPayment({
    required String billId,
    required String memberId,
    required int paidAmount,
    required bool isSettled,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _database.transaction((txn) async {
      await txn.update(
        Tables.billParticipants,
        {'paid_amount': paidAmount, 'settled_at': isSettled ? now : null},
        where: 'bill_id = ? AND member_id = ?',
        whereArgs: [billId, memberId],
      );
      await _refreshStatus(txn, billId, now);
    });
  }

  /// Đánh dấu mọi người đã trả xong (SPEC FR-6.3).
  Future<void> settleAll(String billId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _database.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE ${Tables.billParticipants}
        SET paid_amount = share_amount, settled_at = ?
        WHERE bill_id = ?
        ''',
        [now, billId],
      );
      await txn.update(
        Tables.bills,
        {'status': BillStatus.settled.dbValue, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [billId],
      );
    });
  }

  Future<void> updateStatus(String billId, BillStatus status) async {
    await _db.update(
      Tables.bills,
      {
        'status': status.dbValue,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Các hóa đơn nháp đang chờ hoàn tất (SPEC FR-3.10).
  Future<List<Bill>> getDrafts() => getPage(
    const BillFilter(statuses: {BillStatus.draft}),
    limit: 20,
  );

  // ─────────────────────────── nội bộ ───────────────────────────

  /// Tính lại `bills.status` từ số tiền đã trả của từng người.
  ///
  /// Giữ cùng quy tắc với `Bill.derivedStatus`: người ứng tiền không bị tính
  /// là còn nợ, vì họ đã bỏ tiền ra trước.
  Future<void> _refreshStatus(Transaction txn, String billId, int now) async {
    final rows = await txn.rawQuery(
      '''
      SELECT bp.share_amount, bp.paid_amount,
             EXISTS(
               SELECT 1 FROM ${Tables.billPayers} pay
               WHERE pay.bill_id = bp.bill_id AND pay.member_id = bp.member_id
             ) AS is_payer
      FROM ${Tables.billParticipants} bp
      WHERE bp.bill_id = ?
      ''',
      [billId],
    );

    final owing = rows.where((row) => (row['is_payer']! as int) == 0).toList();

    final BillStatus status;
    if (owing.isEmpty) {
      status = BillStatus.settled;
    } else if (owing.every(
      (row) => (row['paid_amount']! as int) >= (row['share_amount']! as int),
    )) {
      status = BillStatus.settled;
    } else if (owing.any((row) => (row['paid_amount']! as int) > 0)) {
      status = BillStatus.partial;
    } else {
      status = BillStatus.unpaid;
    }

    await txn.update(
      Tables.bills,
      {'status': status.dbValue, 'updated_at': now},
      where: 'id = ? AND status != ?',
      whereArgs: [billId, BillStatus.draft.dbValue],
    );
  }

  (String, List<Object?>) _buildWhere(BillFilter filter) {
    final clauses = <String>['deleted_at IS NULL'];
    final args = <Object?>[];

    if (!filter.includeDrafts) {
      clauses.add('status != ?');
      args.add(BillStatus.draft.dbValue);
    }

    if (filter.statuses.isNotEmpty) {
      final placeholders = List.filled(filter.statuses.length, '?').join(', ');
      clauses.add('status IN ($placeholders)');
      args.addAll(filter.statuses.map((status) => status.dbValue));
    }

    if (filter.query.isNotEmpty) {
      // `filter.query` đã được bỏ dấu ở tầng trên, khớp với `title_norm`.
      clauses.add('title_norm LIKE ?');
      args.add('%${filter.query}%');
    }

    if (filter.range != null) {
      clauses.add('bill_date BETWEEN ? AND ?');
      args.addAll([filter.range!.fromMs, filter.range!.toMs]);
    }

    if (filter.groupId != null) {
      clauses.add('group_id = ?');
      args.add(filter.groupId);
    }

    if (filter.categoryId != null) {
      clauses.add('category_id = ?');
      args.add(filter.categoryId);
    }

    if (filter.memberId != null) {
      clauses.add(
        'id IN (SELECT bill_id FROM ${Tables.billParticipants} '
        'WHERE member_id = ?)',
      );
      args.add(filter.memberId);
    }

    return (clauses.join(' AND '), args);
  }

  Future<Map<String, List<BillParticipant>>> _participantsOf(
    List<String> billIds,
  ) async {
    if (billIds.isEmpty) return const {};

    final placeholders = List.filled(billIds.length, '?').join(', ');
    final rows = await _db.query(
      Tables.billParticipants,
      where: 'bill_id IN ($placeholders)',
      whereArgs: billIds,
      orderBy: 'sort_order ASC',
    );

    final grouped = <String, List<BillParticipant>>{};
    for (final row in rows) {
      final billId = row['bill_id']! as String;
      grouped
          .putIfAbsent(billId, () => [])
          .add(BillParticipant.fromMap(row));
    }
    return grouped;
  }

  Future<Map<String, List<BillPayer>>> _payersOf(List<String> billIds) async {
    if (billIds.isEmpty) return const {};

    final placeholders = List.filled(billIds.length, '?').join(', ');
    final rows = await _db.query(
      Tables.billPayers,
      where: 'bill_id IN ($placeholders)',
      whereArgs: billIds,
    );

    final grouped = <String, List<BillPayer>>{};
    for (final row in rows) {
      final billId = row['bill_id']! as String;
      grouped.putIfAbsent(billId, () => []).add(BillPayer.fromMap(row));
    }
    return grouped;
  }

  Future<Map<String, List<BillItem>>> _itemsOf(List<String> billIds) async {
    if (billIds.isEmpty) return const {};

    final placeholders = List.filled(billIds.length, '?').join(', ');
    final itemRows = await _db.query(
      Tables.billItems,
      where: 'bill_id IN ($placeholders)',
      whereArgs: billIds,
      orderBy: 'sort_order ASC',
    );
    if (itemRows.isEmpty) return const {};

    final itemIds = itemRows.map((row) => row['id']! as String).toList();
    final linkPlaceholders = List.filled(itemIds.length, '?').join(', ');
    final linkRows = await _db.query(
      Tables.billItemParticipants,
      where: 'item_id IN ($linkPlaceholders)',
      whereArgs: itemIds,
    );

    final byItem = <String, List<ItemParticipant>>{};
    for (final row in linkRows) {
      final itemId = row['item_id']! as String;
      byItem
          .putIfAbsent(itemId, () => [])
          .add(ItemParticipant.fromMap(row));
    }

    final grouped = <String, List<BillItem>>{};
    for (final row in itemRows) {
      final billId = row['bill_id']! as String;
      final itemId = row['id']! as String;
      grouped.putIfAbsent(billId, () => []).add(
        BillItem.fromMap(row, participants: byItem[itemId] ?? const []),
      );
    }
    return grouped;
  }
}
