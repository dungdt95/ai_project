import '../../core/utils/date_formatter.dart';
import '../../core/utils/result.dart';
import '../../domain/stats/stats_models.dart';
import '../dao/member_dao.dart';
import '../dao/stats_dao.dart';

/// Nghiệp vụ thống kê (SPEC FR-7).
class StatsRepository {
  const StatsRepository(this._statsDao, this._memberDao);

  final StatsDao _statsDao;
  final MemberDao _memberDao;

  /// Tổng chi phí của từng thành viên (SPEC FR-7.1).
  Future<Result<List<MemberStat>>> memberTotals(DateRange range) =>
      Result.guard(() => _statsDao.memberTotals(range));

  /// Chi phí từng lần theo mỗi hóa đơn của một thành viên (SPEC FR-7.2).
  Future<Result<List<MemberBillEntry>>> memberTimeline(
    String memberId, {
    DateRange? range,
    int? limit,
  }) => Result.guard(
    () => _statsDao.memberTimeline(memberId, range: range, limit: limit),
  );

  /// Tổng chi và số hóa đơn của một thành viên, gộp từ dòng thời gian.
  ///
  /// Dùng cho hai thẻ số ở đầu màn hình chi tiết thành viên (PLAN §5.3, S07).
  Future<Result<MemberSummary>> memberSummary(
    String memberId, {
    DateRange? range,
  }) => Result.guard(() async {
    final entries = await _statsDao.memberTimeline(memberId, range: range);

    var totalSpent = 0;
    var unpaidAmount = 0;
    var unpaidBills = 0;

    for (final entry in entries) {
      totalSpent += entry.shareAmount;
      if (!entry.isSettled) {
        unpaidAmount += entry.remaining;
        unpaidBills++;
      }
    }

    return MemberSummary(
      totalSpent: totalSpent,
      billCount: entries.length,
      unpaidAmount: unpaidAmount,
      unpaidBillCount: unpaidBills,
    );
  });

  /// Tổng chi từng thành viên, bóc theo danh mục (SPEC FR-7.13).
  ///
  /// Gom các dòng của cùng một người lại thành một khối, sắp theo tổng chi
  /// giảm dần — đúng thứ tự của bảng xếp hạng ở ngay trên nó.
  Future<Result<List<MemberBreakdown>>> memberBreakdowns(DateRange range) =>
      Result.guard(() async {
        final rows = await _statsDao.memberCategoryTotals(range);

        final byMember = <String, List<MemberCategoryStat>>{};
        for (final row in rows) {
          (byMember[row.memberId] ??= []).add(row);
        }

        final breakdowns = [
          for (final entry in byMember.entries)
            MemberBreakdown(
              memberId: entry.key,
              memberName: entry.value.first.memberName,
              avatarColor: entry.value.first.avatarColor,
              rows: entry.value,
            ),
        ]..sort((a, b) => b.total.compareTo(a.total));

        return breakdowns;
      });

  Future<Result<List<WeeklyStat>>> weeklyTotals({int weeks = 12}) =>
      Result.guard(() => _statsDao.weeklyTotals(weeks: weeks));

  Future<Result<List<MonthlyStat>>> monthlyTotals({int months = 12}) =>
      Result.guard(() => _statsDao.monthlyTotals(months: months));

  Future<Result<List<CategoryStat>>> categoryTotals(DateRange range) =>
      Result.guard(() => _statsDao.categoryTotals(range));

  Future<Result<DashboardSummary>> dashboard() => Result.guard(() async {
    final self = await _memberDao.getSelf();
    return _statsDao.dashboard(self?.id);
  });

  Future<Result<int>> groupTotal(String groupId, DateRange range) =>
      Result.guard(() => _statsDao.groupTotal(groupId, range));
}

/// Hai thẻ số ở đầu màn hình chi tiết thành viên.
class MemberSummary {
  const MemberSummary({
    required this.totalSpent,
    required this.billCount,
    required this.unpaidAmount,
    required this.unpaidBillCount,
  });

  static const MemberSummary empty = MemberSummary(
    totalSpent: 0,
    billCount: 0,
    unpaidAmount: 0,
    unpaidBillCount: 0,
  );

  final int totalSpent;
  final int billCount;
  final int unpaidAmount;
  final int unpaidBillCount;

  int get averagePerBill => billCount == 0 ? 0 : totalSpent ~/ billCount;
}
