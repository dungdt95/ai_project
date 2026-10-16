import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/app_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/member.dart';
import '../../domain/stats/stats_models.dart';
import '../members/member_detail_screen.dart';
import '../members/members_provider.dart';
import 'report_share_screen.dart';
import 'stats_provider.dart';

/// S11 — Thống kê (SPEC FR-7).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// Khóa của thanh chọn kỳ, dùng trong widget test.
  static const String periodBarKey = 'stats-period-bar';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final period = ref.watch(statsPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  key: const Key(StatsScreen.periodBarKey),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
                  children: [
                    for (final value in StatsPeriod.values) ...[
                      ChoiceChip(
                        label: Text(value.label),
                        selected: period == value,
                        onSelected: (_) =>
                            ref.read(statsPeriodProvider.notifier).set(value),
                      ),
                      const SizedBox(width: AppTheme.s8),
                    ],
                  ],
                ),
              ),
              // "Tuần trước" thì người đọc vẫn phải tự đếm lùi xem là những
              // ngày nào — nên ghi thẳng khoảng ngày ra đây.
              PeriodRangeLabel(range: period.range),
            ],
          ),
        ),
      ),
      body: switch (stats) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => ErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(statsProvider),
        ),
        AsyncData(:final value) =>
          value.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'Chưa có số liệu',
                  message: 'Tạo hóa đơn để xem ai đã chi bao nhiêu.',
                )
              : _Content(view: value),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.view});

  final StatsView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in members) member.id: member};

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              children: [
                Text(
                  'Tổng chi của cả nhóm',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.s4),
                FittedBox(
                  child: Text(
                    view.grandTotal.toVnd(),
                    style: MoneyTextStyle.large,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.s24),

        const _SectionTitle('TỔNG CHI PHÍ TỪNG THÀNH VIÊN'),
        const SizedBox(height: AppTheme.s8),
        _MemberRanking(stats: view.members, members: byId),

        if (view.members.length > 1) ...[
          const SizedBox(height: AppTheme.s24),
          const _SectionTitle('TỶ TRỌNG THEO NGƯỜI'),
          const SizedBox(height: AppTheme.s8),
          _SharePie(stats: view.members, total: view.grandTotal),
        ],

        const SizedBox(height: AppTheme.s24),
        const _TrendSection(),

        if (view.categories.isNotEmpty) ...[
          const SizedBox(height: AppTheme.s24),
          const _SectionTitle('THEO DANH MỤC'),
          const SizedBox(height: AppTheme.s8),
          _CategoryList(stats: view.categories, total: view.grandTotal),
        ],

        if (view.breakdowns.isNotEmpty) ...[
          const SizedBox(height: AppTheme.s24),
          const _SectionTitle('CHI PHÍ TỪNG NGƯỜI THEO DANH MỤC'),
          const SizedBox(height: AppTheme.s8),
          _CategoryMemberSection(view: view, members: byId),
        ],

        const SizedBox(height: AppTheme.s32),
      ],
    );
  }
}

/// Chi phí của từng thành viên **trong một danh mục** (SPEC FR-7.13).
///
/// Chọn danh mục ở ô trên cùng, bên dưới là ai tốn bao nhiêu trong danh mục đó.
/// Cách này đọc thẳng được câu người dùng hay hỏi — "tháng này ai ăn uống nhiều
/// nhất" — thay vì phải mở từng người ra rồi tự so.
class _CategoryMemberSection extends ConsumerWidget {
  const _CategoryMemberSection({required this.view, required this.members});

  /// Khóa của thanh tỷ trọng từng người, dùng trong widget test.
  static String barKeyFor(String memberId) => 'category-member-bar-$memberId';

  static const String dropdownKey = 'category-member-dropdown';

  final StatsView view;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = ref.watch(hiddenMembersProvider);
    final selected = ref.watch(statsCategoryProvider);

    // Đổi kỳ thì danh mục đang chọn có thể không còn hóa đơn nào. Quay về "tất
    // cả" thay vì để ô chọn trỏ vào một giá trị không có trong danh sách —
    // `DropdownButton` ném lỗi khi `value` không khớp item nào.
    final available = view.categories.map((stat) => stat.categoryId).toSet();
    final isAll = selected == kAllCategories || !available.contains(selected);

    final rows = membersInCategory(
      view.breakdowns,
      categoryId: selected,
      allCategories: isAll,
      hidden: hidden,
    );
    final max = rows.isEmpty ? 0 : rows.first.total;
    final total = rows.fold(0, (sum, row) => sum + row.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key(dropdownKey),
                initialValue: isAll ? kAllCategories : selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: kAllCategories,
                    child: Text('Tất cả danh mục'),
                  ),
                  for (final category in view.categories)
                    DropdownMenuItem(
                      value: category.categoryId,
                      child: Text(
                        '${category.icon ?? ''} ${category.categoryName}'
                            .trim(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    ref.read(statsCategoryProvider.notifier).set(value),
              ),
            ),
            const SizedBox(width: AppTheme.s8),
            IconButton.outlined(
              tooltip: 'Chọn thành viên hiển thị',
              icon: Badge(
                isLabelVisible: hidden.isNotEmpty,
                label: Text('${hidden.length}'),
                child: const Icon(Icons.visibility_off_outlined),
              ),
              onPressed: () => _pickMembers(context, ref),
            ),
            const SizedBox(width: AppTheme.s8),
            IconButton.outlined(
              tooltip: 'Chia sẻ báo cáo',
              icon: const Icon(Icons.ios_share),
              // Không có gì để chia sẻ thì tắt nút, thay vì gửi đi một bảng
              // rỗng mà người nhận không hiểu là lỗi hay là thật.
              onPressed: rows.isEmpty
                  ? null
                  : () => ReportShareScreen.push(
                      context,
                      categoryName: isAll
                          ? 'Tất cả danh mục'
                          : rows.first.categoryName,
                      periodDetail: ref.read(statsPeriodProvider).range.detail,
                      rows: rows,
                      hiddenCount: hidden.length,
                      // Người đang cầm máy chia sẻ báo cáo để thu tiền, nên lấy
                      // tài khoản của "Tôi" (SPEC FR-8.8).
                      payee: members.values
                          .where((member) => member.isSelf)
                          .firstOrNull,
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),

        if (rows.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.s16),
              child: Text(
                hidden.isEmpty
                    ? 'Chưa ai chi trong danh mục này.'
                    : 'Những người còn hiện chưa chi gì trong danh mục này.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.s8),
              child: Column(
                children: [
                  for (final row in rows)
                    _CategoryMemberRow(
                      row: row,
                      max: max,
                      total: total,
                      isSelf: members[row.memberId]?.isSelf ?? false,
                      onTap: members[row.memberId] == null
                          ? null
                          : () => MemberDetailScreen.push(
                              context,
                              members[row.memberId]!,
                            ),
                    ),
                ],
              ),
            ),
          ),

        if (hidden.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.s4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Đang ẩn ${hidden.length} người khỏi mục này',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(hiddenMembersProvider.notifier).showAll(),
                  child: const Text('Hiện lại'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Bảng chọn ai được hiện trong mục này (SPEC FR-7.14).
  void _pickMembers(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final hidden = ref.watch(hiddenMembersProvider);
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.s16,
                    0,
                    AppTheme.s16,
                    AppTheme.s8,
                  ),
                  child: Text(
                    'Thành viên hiển thị',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final breakdown in view.breakdowns)
                  CheckboxListTile(
                    value: !hidden.contains(breakdown.memberId),
                    onChanged: (_) => ref
                        .read(hiddenMembersProvider.notifier)
                        .toggle(breakdown.memberId),
                    secondary: MemberAvatar.small(
                      name: breakdown.memberName,
                      color: breakdown.avatarColor,
                      isSelf: members[breakdown.memberId]?.isSelf ?? false,
                    ),
                    title: Text(breakdown.memberName),
                    // Nói rõ "cả kỳ": danh sách bên dưới có thể đang lọc theo
                    // một danh mục, số ở đây thì không.
                    subtitle: Text('Cả kỳ: ${breakdown.total.toVnd()}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Một dòng người trong báo cáo theo danh mục.
class _CategoryMemberRow extends StatelessWidget {
  const _CategoryMemberRow({
    required this.row,
    required this.max,
    required this.total,
    required this.isSelf,
    this.onTap,
  });

  final MemberCategoryStat row;

  /// Số tiền của người cao nhất, để thanh dài nhất chạm mép phải.
  final int max;

  /// Tổng của những người đang hiện, dùng để tính phần trăm.
  final int total;

  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total == 0 ? 0 : (row.total * 100 / total).round();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.s16,
          vertical: AppTheme.s8,
        ),
        child: Column(
          children: [
            Row(
              children: [
                MemberAvatar.small(
                  name: row.memberName,
                  color: row.avatarColor,
                  isSelf: isSelf,
                ),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  child: Text(
                    row.memberName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppTheme.s8),
                Text(row.total.toVnd(), style: MoneyTextStyle.small),
              ],
            ),
            const SizedBox(height: AppTheme.s4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: Key(_CategoryMemberSection.barKeyFor(row.memberId)),
                value: max == 0 ? 0 : row.total / max,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.s4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${row.billCount} hóa đơn · $percent%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dòng nói rõ kỳ đang xem là từ ngày nào tới ngày nào.
///
/// Dùng chung cho màn Thống kê và màn chi tiết thành viên, để hai nơi không
/// diễn đạt cùng một kỳ theo hai kiểu khác nhau.
class PeriodRangeLabel extends StatelessWidget {
  const PeriodRangeLabel({required this.range, super.key});

  final DateRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Canh trái thẳng hàng với chip ở trên: hai thứ nói về cùng một kỳ, lệch
      // nhau thì mắt không nối được chúng với nhau.
      padding: const EdgeInsets.fromLTRB(
        AppTheme.s16,
        0,
        AppTheme.s16,
        AppTheme.s8,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          range.detail,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Bảng xếp hạng thành viên theo tổng chi (SPEC FR-7.1, FR-7.4).
///
/// Dùng thanh ngang có nhãn trực tiếp thay vì biểu đồ cột: ở bề ngang điện
/// thoại, tên người dưới trục cột sẽ phải xoay nghiêng hoặc cắt bớt. Đây là
/// biểu đồ **độ lớn**, không phải phân loại, nên mọi thanh dùng chung một màu —
/// tên bên cạnh mới là thứ phân biệt.
class _MemberRanking extends StatelessWidget {
  const _MemberRanking({required this.stats, required this.members});

  final List<MemberStat> stats;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = stats.isEmpty ? 1 : stats.first.totalSpent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.s8),
        child: Column(
          children: [
            for (final stat in stats)
              InkWell(
                onTap: members[stat.memberId] == null
                    ? null
                    : () => MemberDetailScreen.push(
                        context,
                        members[stat.memberId]!,
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.s16,
                    vertical: AppTheme.s8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          MemberAvatar.small(
                            name: stat.memberName,
                            color: stat.avatarColor,
                            isSelf: members[stat.memberId]?.isSelf ?? false,
                          ),
                          const SizedBox(width: AppTheme.s12),
                          Expanded(
                            child: Text(
                              stat.memberName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppTheme.s8),
                          Text(
                            stat.totalSpent.toVnd(),
                            style: MoneyTextStyle.small,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.s4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : stat.totalSpent / max,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.s4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${stat.billCount} hóa đơn · trung bình '
                          '${stat.averagePerBill.toVnd()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Biểu đồ tròn tỷ trọng chi phí theo người (SPEC FR-7.5).
///
/// Đây là biểu đồ **phân loại**, nên dùng bảng màu đã qua kiểm định ở
/// `AppColors.chartPaletteFor`. Quá 6 người thì phần còn lại gom vào "Khác"
/// thay vì sinh thêm màu. Luôn có chú giải kèm tên và số tiền, nên danh tính
/// không bao giờ chỉ dựa vào màu.
class _SharePie extends StatelessWidget {
  const _SharePie({required this.stats, required this.total});

  static const int maxSlices = 6;

  final List<MemberStat> stats;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppColors.chartPaletteFor(theme.brightness);

    final visible = stats.take(maxSlices).toList();
    final hiddenTotal = stats
        .skip(maxSlices)
        .fold<int>(0, (sum, stat) => sum + stat.totalSpent);

    final slices = <({String name, int amount, Color color})>[
      for (var i = 0; i < visible.length; i++)
        (
          name: visible[i].memberName,
          amount: visible[i].totalSpent,
          color: palette[i % palette.length],
        ),
      if (hiddenTotal > 0)
        (
          name: 'Khác (${stats.length - maxSlices} người)',
          amount: hiddenTotal,
          color: AppColors.chartOther,
        ),
    ];

    if (total <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.amount.toDouble(),
                        color: slice.color,
                        radius: 44,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            // Chú giải: tên và số tiền đi kèm, nên biểu đồ không phụ thuộc
            // hoàn toàn vào việc phân biệt màu.
            for (final slice in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppTheme.s8),
                    Expanded(
                      child: Text(
                        slice.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${(slice.amount * 100 / total).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppTheme.s8),
                    Text(slice.amount.toVnd(), style: MoneyTextStyle.small),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khối "tổng chi theo thời gian", kèm nút chuyển giữa tuần và tháng.
///
/// Dữ liệu của cả hai cách gộp đều đã nằm sẵn trong [statsProvider], nên đổi
/// qua lại không phải hỏi lại DB và biểu đồ không nháy.
class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  /// Khóa của nút chuyển, dùng trong widget test.
  static const String toggleKey = 'trend-grouping-toggle';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(statsProvider).value;
    if (view == null) return const SizedBox.shrink();

    final grouping = ref.watch(trendGroupingProvider);

    final points = switch (grouping) {
      TrendGrouping.weekly => [
        for (final week in view.weekly)
          (label: week.label, tooltip: week.rangeLabel, total: week.total),
      ],
      TrendGrouping.monthly => [
        for (final month in view.monthly)
          (
            label: month.label,
            tooltip: 'Tháng ${month.month}/${month.year}',
            total: month.total,
          ),
      ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                grouping == TrendGrouping.weekly
                    ? 'TỔNG CHI THEO TUẦN'
                    : 'TỔNG CHI THEO THÁNG',
              ),
            ),
            SegmentedButton<TrendGrouping>(
              key: const Key(toggleKey),
              segments: [
                for (final value in TrendGrouping.values)
                  ButtonSegment(value: value, label: Text(value.label)),
              ],
              selected: {grouping},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (selection) =>
                  ref.read(trendGroupingProvider.notifier).set(selection.first),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),

        if (points.length < 2)
          _NotEnoughData(grouping: grouping)
        else
          _TrendChart(points: points),
      ],
    );
  }
}

/// Nói rõ vì sao chưa vẽ được biểu đồ, thay vì để một khoảng trống.
class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData({required this.grouping});

  final TrendGrouping grouping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = grouping == TrendGrouping.weekly ? 'tuần' : 'tháng';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Text(
          'Cần hóa đơn của ít nhất hai $unit mới vẽ được biểu đồ so sánh.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Một cột của biểu đồ xu hướng.
///
/// [tooltip] nói rõ cột đó là kỳ nào — với cột tuần thì đó là khoảng ngày, vì
/// nhìn nhãn "29/09" không biết tuần ấy kéo tới đâu.
typedef TrendPoint = ({String label, String tooltip, int total});

/// Tổng chi theo thời gian, gộp theo tuần hoặc theo tháng (SPEC FR-7.6).
///
/// Biểu đồ độ lớn theo thời gian nên mọi cột dùng một màu; trục dưới ghi kỳ.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = points
        .map((point) => point.total)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.s8,
          AppTheme.s24,
          AppTheme.s16,
          AppTheme.s8,
        ),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValue * 1.15,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxValue / 2,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: maxValue / 2,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.round().toVndCompact(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          points[index].label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${points[group.x].tooltip}\n${rod.toY.round().toVnd()}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].total.toDouble(),
                        color: theme.colorScheme.primary,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tổng chi theo danh mục (SPEC FR-7.7).
class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.stats, required this.total});

  final List<CategoryStat> stats;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          for (final stat in stats)
            ListTile(
              leading: Text(
                stat.icon ?? '📦',
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(stat.categoryName),
              subtitle: Text(
                '${stat.billCount} hóa đơn'
                '${total > 0 ? ' · ${(stat.total * 100 / total).round()}%' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Text(stat.total.toVnd(), style: MoneyTextStyle.small),
            ),
        ],
      ),
    );
  }
}
