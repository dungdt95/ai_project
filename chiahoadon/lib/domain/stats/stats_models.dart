import '../../core/utils/date_formatter.dart';
import '../models/enums.dart';

/// Tổng chi phí của một thành viên trong một khoảng thời gian (SPEC FR-7.1).
class MemberStat {
  const MemberStat({
    required this.memberId,
    required this.memberName,
    required this.avatarColor,
    required this.totalSpent,
    required this.billCount,
  });

  factory MemberStat.fromRow(Map<String, Object?> row) => MemberStat(
    memberId: row['member_id']! as String,
    memberName: row['member_name']! as String,
    avatarColor: row['avatar_color']! as int,
    totalSpent: (row['total_spent'] as int?) ?? 0,
    billCount: (row['bill_count'] as int?) ?? 0,
  );

  final String memberId;
  final String memberName;
  final int avatarColor;

  /// Tổng số tiền người này phải chịu.
  final int totalSpent;

  final int billCount;

  /// Chi phí bình quân mỗi hóa đơn.
  int get averagePerBill => billCount == 0 ? 0 : totalSpent ~/ billCount;

  @override
  String toString() => 'MemberStat($memberName, $totalSpent, $billCount hóa đơn)';
}

/// Một dòng trong lịch sử chi phí của một thành viên (SPEC FR-7.2).
///
/// Đây chính là "chi phí từng lần theo mỗi hóa đơn" mà yêu cầu gốc đặt ra.
class MemberBillEntry {
  const MemberBillEntry({
    required this.billId,
    required this.title,
    required this.billDate,
    required this.billTotal,
    required this.shareAmount,
    required this.paidAmount,
    required this.status,
    this.categoryName,
    this.categoryIcon,
    this.settledAt,
  });

  factory MemberBillEntry.fromRow(Map<String, Object?> row) =>
      MemberBillEntry(
        billId: row['bill_id']! as String,
        title: row['title']! as String,
        billDate: row['bill_date']! as int,
        billTotal: row['total_amount']! as int,
        shareAmount: row['share_amount']! as int,
        paidAmount: row['paid_amount']! as int,
        status: BillStatus.fromDb(row['status'] as String?),
        categoryName: row['category_name'] as String?,
        categoryIcon: row['category_icon'] as String?,
        settledAt: row['settled_at'] as int?,
      );

  final String billId;
  final String title;
  final int billDate;

  /// Tổng của cả hóa đơn, để thấy phần của mình chiếm bao nhiêu.
  final int billTotal;

  /// Số tiền người này phải chịu trong hóa đơn này.
  final int shareAmount;

  final int paidAmount;
  final BillStatus status;
  final String? categoryName;
  final String? categoryIcon;
  final int? settledAt;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(billDate);

  bool get isSettled => settledAt != null || paidAmount >= shareAmount;

  int get remaining => shareAmount - paidAmount;

  ParticipantPaymentStatus get paymentStatus {
    if (paidAmount <= 0) return ParticipantPaymentStatus.unpaid;
    if (paidAmount >= shareAmount) return ParticipantPaymentStatus.paid;
    return ParticipantPaymentStatus.partial;
  }
}

/// Tổng chi theo tháng, dùng cho biểu đồ 12 tháng (SPEC FR-7.6).
class MonthlyStat {
  const MonthlyStat({
    required this.monthKey,
    required this.total,
    required this.billCount,
  });

  factory MonthlyStat.fromRow(Map<String, Object?> row) => MonthlyStat(
    monthKey: row['ym']! as String,
    total: (row['total'] as int?) ?? 0,
    billCount: (row['cnt'] as int?) ?? 0,
  );

  /// Dạng `2026-10`, khớp `strftime('%Y-%m')` của SQLite.
  final String monthKey;

  final int total;
  final int billCount;

  int get year => int.parse(monthKey.split('-')[0]);

  int get month => int.parse(monthKey.split('-')[1]);

  String get label => 'T$month';
}

/// Tổng chi theo tuần.
///
/// Tuần tính từ thứ Hai, theo cách người Việt nói "tuần này" — không theo chuẩn
/// ISO hay theo tuần bắt đầu Chủ nhật của Mỹ.
class WeeklyStat {
  const WeeklyStat({
    required this.weekStart,
    required this.total,
    required this.billCount,
  });

  factory WeeklyStat.fromRow(Map<String, Object?> row) => WeeklyStat(
    weekStart: row['wk']! as String,
    total: (row['total'] as int?) ?? 0,
    billCount: (row['cnt'] as int?) ?? 0,
  );

  /// Ngày thứ Hai của tuần, dạng `2026-09-29` — khớp `date()` của SQLite.
  final String weekStart;

  final int total;
  final int billCount;

  DateTime get start => DateTime.parse(weekStart);

  DateTime get end => start.add(const Duration(days: 6));

  /// Nhãn ngắn cho trục biểu đồ: `29/09`.
  String get label => DateFormatter.dayMonth(start);

  /// Nói rõ tuần này là từ ngày nào tới ngày nào.
  String get rangeLabel => DateFormatter.span(start, end);
}

/// Tổng chi theo danh mục (SPEC FR-7.7).
class CategoryStat {
  const CategoryStat({
    required this.categoryName,
    required this.color,
    required this.total,
    required this.billCount,
    this.categoryId,
    this.icon,
  });

  factory CategoryStat.fromRow(Map<String, Object?> row) => CategoryStat(
    categoryId: row['category_id'] as String?,
    categoryName: (row['category_name'] as String?) ?? 'Chưa phân loại',
    icon: row['category_icon'] as String?,
    color: (row['category_color'] as int?) ?? 0xFF6B7280,
    total: (row['total'] as int?) ?? 0,
    billCount: (row['cnt'] as int?) ?? 0,
  );

  final String? categoryId;
  final String categoryName;
  final String? icon;
  final int color;
  final int total;
  final int billCount;
}

/// Một ô của bảng chéo **thành viên × danh mục** (SPEC FR-7.13).
///
/// Trả lời câu "An tiêu bao nhiêu vào ăn uống, bao nhiêu vào đi lại" — khác với
/// [CategoryStat] vốn chỉ nói cả nhóm tiêu bao nhiêu vào mỗi danh mục.
class MemberCategoryStat {
  const MemberCategoryStat({
    required this.memberId,
    required this.memberName,
    required this.avatarColor,
    required this.categoryName,
    required this.total,
    required this.billCount,
    this.categoryId,
    this.icon,
  });

  factory MemberCategoryStat.fromRow(Map<String, Object?> row) =>
      MemberCategoryStat(
        memberId: row['member_id']! as String,
        memberName: row['member_name']! as String,
        avatarColor: row['avatar_color']! as int,
        categoryId: row['category_id'] as String?,
        categoryName: (row['category_name'] as String?) ?? 'Chưa phân loại',
        icon: row['category_icon'] as String?,
        total: (row['total'] as int?) ?? 0,
        billCount: (row['cnt'] as int?) ?? 0,
      );

  final String memberId;
  final String memberName;
  final int avatarColor;

  /// `null` khi hóa đơn chưa chọn danh mục nào.
  final String? categoryId;

  final String categoryName;
  final String? icon;

  /// Số tiền người này phải chịu trong danh mục này.
  final int total;

  final int billCount;

  @override
  String toString() =>
      'MemberCategoryStat($memberName / $categoryName: $total)';
}

/// Chi tiêu của một thành viên, bóc theo danh mục (SPEC FR-7.13).
class MemberBreakdown {
  const MemberBreakdown({
    required this.memberId,
    required this.memberName,
    required this.avatarColor,
    required this.rows,
  });

  final String memberId;
  final String memberName;
  final int avatarColor;

  /// Các danh mục người này có chi, nhiều tiền trước.
  final List<MemberCategoryStat> rows;

  int get total => rows.fold(0, (sum, row) => sum + row.total);

  /// Danh mục tốn nhất của người này, hoặc `null` nếu chưa chi gì.
  MemberCategoryStat? get top => rows.isEmpty ? null : rows.first;

  /// Tỷ trọng của một danh mục trong tổng chi của người này, dạng 0–1.
  double ratioOf(MemberCategoryStat row) =>
      total == 0 ? 0 : row.total / total;

  /// Phần của người này trong một danh mục, `null` nếu không chi gì ở đó.
  MemberCategoryStat? rowOf(String? categoryId) {
    for (final row in rows) {
      if (row.categoryId == categoryId) return row;
    }
    return null;
  }

  /// Gộp mọi danh mục của người này thành một dòng.
  MemberCategoryStat get combined => MemberCategoryStat(
    memberId: memberId,
    memberName: memberName,
    avatarColor: avatarColor,
    categoryName: 'Tất cả danh mục',
    total: total,
    billCount: rows.fold(0, (sum, row) => sum + row.billCount),
  );
}

/// Chi phí của từng thành viên **trong một danh mục** (SPEC FR-7.13).
///
/// Lật ngược bảng chéo: [MemberBreakdown] là "một người tiêu vào những việc gì",
/// hàm này là "một việc tốn tiền của những ai". Giữ ở tầng domain để test được
/// mà không cần dựng giao diện.
///
/// [allCategories] đúng thì gộp hết mọi danh mục; nếu không thì lọc theo
/// [categoryId], trong đó `null` là nhóm "Chưa phân loại". Người có tên trong
/// [hidden] bị bỏ hẳn khỏi kết quả — kể cả khỏi tổng, vì nếu còn trong tổng thì
/// các phần trăm cộng lại không ra 100% và người đọc không hiểu vì sao
/// (SPEC FR-7.14).
List<MemberCategoryStat> membersInCategory(
  List<MemberBreakdown> breakdowns, {
  String? categoryId,
  bool allCategories = false,
  Set<String> hidden = const {},
}) {
  final result = <MemberCategoryStat>[];
  for (final breakdown in breakdowns) {
    if (hidden.contains(breakdown.memberId)) continue;
    final row = allCategories
        ? breakdown.combined
        : breakdown.rowOf(categoryId);
    if (row != null && row.total > 0) result.add(row);
  }
  result.sort((a, b) => b.total.compareTo(a.total));
  return result;
}

/// Số dư ròng của một thành viên (SPEC FR-6.4).
///
/// Bất biến của hệ thống: tổng [balance] của mọi thành viên luôn bằng 0.
class MemberBalance {
  const MemberBalance({
    required this.memberId,
    required this.memberName,
    required this.avatarColor,
    required this.advanced,
    required this.owed,
    required this.sent,
    required this.received,
  });

  factory MemberBalance.fromRow(Map<String, Object?> row) => MemberBalance(
    memberId: row['member_id']! as String,
    memberName: row['member_name']! as String,
    avatarColor: row['avatar_color']! as int,
    advanced: (row['advanced'] as int?) ?? 0,
    owed: (row['owed'] as int?) ?? 0,
    sent: (row['sent'] as int?) ?? 0,
    received: (row['received'] as int?) ?? 0,
  );

  final String memberId;
  final String memberName;
  final int avatarColor;

  /// Tổng tiền đã ứng trả thay cả nhóm.
  final int advanced;

  /// Tổng phần phải chịu.
  final int owed;

  /// Tổng tiền đã chuyển cho người khác (bảng `payments`).
  final int sent;

  /// Tổng tiền đã nhận từ người khác.
  final int received;

  /// Dương: người khác nợ mình. Âm: mình nợ người khác.
  int get balance => advanced - owed + sent - received;

  bool get isCreditor => balance > 0;

  bool get isDebtor => balance < 0;

  bool get isClear => balance == 0;

  @override
  String toString() => 'MemberBalance($memberName, ${balance >= 0 ? '+' : ''}$balance)';
}

/// Các chỉ số trên Dashboard (SPEC FR-7.8).
class DashboardSummary {
  const DashboardSummary({
    required this.monthTotal,
    required this.monthBillCount,
    required this.owedToMe,
    required this.iOwe,
    required this.unsettledBillCount,
  });

  static const DashboardSummary empty = DashboardSummary(
    monthTotal: 0,
    monthBillCount: 0,
    owedToMe: 0,
    iOwe: 0,
    unsettledBillCount: 0,
  );

  /// Tổng chi tháng này của riêng người dùng ("Tôi").
  final int monthTotal;

  final int monthBillCount;

  /// Tổng tiền người khác đang nợ mình.
  final int owedToMe;

  /// Tổng tiền mình đang nợ người khác.
  final int iOwe;

  final int unsettledBillCount;
}
