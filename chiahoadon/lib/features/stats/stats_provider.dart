import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/stats_repository.dart';
import '../../domain/stats/stats_models.dart';
import '../bills/bills_provider.dart';

/// Khoảng thời gian đang xem ở màn hình thống kê (SPEC FR-7.3).
enum StatsPeriod {
  thisWeek('Tuần này'),
  lastWeek('Tuần trước'),
  thisMonth('Tháng này'),
  lastMonth('Tháng trước'),
  last3Months('3 tháng'),
  thisYear('Năm nay'),
  allTime('Tất cả');

  const StatsPeriod(this.label);

  final String label;

  DateRange get range => switch (this) {
    StatsPeriod.thisWeek => DateRange.thisWeek(),
    StatsPeriod.lastWeek => DateRange.lastWeek(),
    StatsPeriod.thisMonth => DateRange.thisMonth(),
    StatsPeriod.lastMonth => DateRange.lastMonth(),
    StatsPeriod.last3Months => DateRange.last3Months(),
    StatsPeriod.thisYear => DateRange.thisYear(),
    StatsPeriod.allTime => DateRange.allTime(),
  };
}

/// Biểu đồ xu hướng đang gộp theo tuần hay theo tháng.
enum TrendGrouping {
  weekly('Tuần'),
  monthly('Tháng');

  const TrendGrouping(this.label);

  final String label;
}

class TrendGroupingNotifier extends Notifier<TrendGrouping> {
  @override
  TrendGrouping build() => TrendGrouping.monthly;

  void set(TrendGrouping value) => state = value;
}

final trendGroupingProvider =
    NotifierProvider<TrendGroupingNotifier, TrendGrouping>(
      TrendGroupingNotifier.new,
    );

/// Giá trị "tất cả danh mục" của ô chọn danh mục (SPEC FR-7.13).
///
/// Phải là một chuỗi riêng chứ không dùng `null`: `null` đã mang nghĩa khác —
/// nhóm hóa đơn **chưa phân loại**. Dạng `__tất_cả__` không trùng được với id
/// danh mục (id là uuid).
const String kAllCategories = '__all__';

/// Danh mục đang xem ở báo cáo "chi phí theo danh mục".
class StatsCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => kAllCategories;

  void set(String? categoryId) => state = categoryId;
}

final statsCategoryProvider = NotifierProvider<StatsCategoryNotifier, String?>(
  StatsCategoryNotifier.new,
);

/// Những thành viên đang bị ẩn khỏi báo cáo theo danh mục (SPEC FR-7.14).
///
/// Chỉ ảnh hưởng mục đó, không đụng tới bảng xếp hạng hay tổng chi của nhóm:
/// ẩn một người khỏi *mọi* con số sẽ làm tổng trên màn hình không còn khớp với
/// tổng thật của nhóm.
class HiddenMembersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String memberId) => state = {
    ...state.contains(memberId)
        ? (state.toSet()..remove(memberId))
        : (state.toSet()..add(memberId)),
  };

  void showAll() => state = const {};
}

final hiddenMembersProvider =
    NotifierProvider<HiddenMembersNotifier, Set<String>>(
      HiddenMembersNotifier.new,
    );

class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.thisMonth;

  void set(StatsPeriod value) => state = value;
}

final statsPeriodProvider = NotifierProvider<StatsPeriodNotifier, StatsPeriod>(
  StatsPeriodNotifier.new,
);

/// Mọi số liệu của màn hình thống kê, gom vào một lần đọc.
class StatsView {
  const StatsView({
    required this.members,
    required this.weekly,
    required this.monthly,
    required this.categories,
    required this.breakdowns,
  });

  /// Tổng chi phí từng thành viên, giảm dần (SPEC FR-7.1).
  final List<MemberStat> members;

  /// Tổng chi theo tuần, cũ → mới.
  final List<WeeklyStat> weekly;

  /// Tổng chi theo tháng, cũ → mới (SPEC FR-7.6).
  final List<MonthlyStat> monthly;

  /// Tổng chi theo danh mục (SPEC FR-7.7).
  final List<CategoryStat> categories;

  /// Tổng chi từng thành viên, bóc theo danh mục (SPEC FR-7.13).
  final List<MemberBreakdown> breakdowns;

  int get grandTotal => members.fold(0, (sum, stat) => sum + stat.totalSpent);

  int get billCount => categories.fold(0, (sum, stat) => sum + stat.billCount);

  bool get isEmpty => members.isEmpty;
}

/// Số liệu thống kê theo kỳ đang chọn.
final statsProvider = FutureProvider<StatsView>((ref) async {
  // Mọi thay đổi hóa đơn đều làm đổi số liệu.
  ref.watch(billListProvider);

  final period = ref.watch(statsPeriodProvider);
  final repository = ref.watch(statsRepositoryProvider);
  final range = period.range;

  final members = await repository.memberTotals(range);
  final weekly = await repository.weeklyTotals();
  final monthly = await repository.monthlyTotals();
  final categories = await repository.categoryTotals(range);
  final breakdowns = await repository.memberBreakdowns(range);

  return StatsView(
    members: members.when(ok: (list) => list, err: (error) => throw error),
    // DAO trả mới nhất trước; biểu đồ đọc trái sang phải nên đảo lại.
    weekly: weekly.valueOr(const []).reversed.toList(),
    monthly: monthly.valueOr(const []).reversed.toList(),
    categories: categories
        .valueOr(const [])
        .where((stat) => stat.total > 0)
        .toList(),
    breakdowns: breakdowns.valueOr(const []),
  );
});

/// Chỉ số trên Dashboard (SPEC FR-7.8).
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(billListProvider);

  final result = await ref.watch(statsRepositoryProvider).dashboard();
  return result.valueOr(DashboardSummary.empty);
});

/// Tổng chi và số hóa đơn của một thành viên (SPEC FR-7.1).
final memberSummaryProvider =
    FutureProvider.family<
      MemberSummary,
      ({String memberId, StatsPeriod period})
    >((ref, args) async {
      ref.watch(billListProvider);

      final result = await ref
          .watch(statsRepositoryProvider)
          .memberSummary(
            args.memberId,
            range: args.period == StatsPeriod.allTime
                ? null
                : args.period.range,
          );
      return result.valueOr(MemberSummary.empty);
    });

/// Chi phí từng lần theo mỗi hóa đơn của một thành viên (SPEC FR-7.2).
///
/// Đây chính là yêu cầu gốc "thống kê chi phí theo từng thành viên, cần biết
/// tổng chi phí và chi phí từng lần theo mỗi hóa đơn".
final memberTimelineProvider =
    FutureProvider.family<
      List<MemberBillEntry>,
      ({String memberId, StatsPeriod period})
    >((ref, args) async {
      ref.watch(billListProvider);

      final result = await ref
          .watch(statsRepositoryProvider)
          .memberTimeline(
            args.memberId,
            range: args.period == StatsPeriod.allTime
                ? null
                : args.period.range,
          );
      return result.valueOr(const []);
    });
