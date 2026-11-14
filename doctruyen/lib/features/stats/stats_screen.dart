import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/data_providers.dart';
import '../../domain/stats/stats_aggregator.dart';
import '../library/library_provider.dart';

final statsSummaryProvider = FutureProvider.autoDispose<StatsSummary>((
  ref,
) async {
  // Ghi phần đang chờ xuống DB để số liệu mới nhất.
  await ref.read(activityTrackerProvider).flush();
  return ref.read(statsRepositoryProvider).summary();
});

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(statsSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê đọc')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(streak: s.streak),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TotalsCard(label: 'Hôm nay', totals: s.today),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TotalsCard(label: '7 ngày', totals: s.last7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TotalsCard(label: '30 ngày', totals: s.last30),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Biểu đồ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 ngày')),
                      ButtonSegment(value: 30, label: Text('30 ngày')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (v) => setState(() => _range = v.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _DayChart(days: s.days.sublist(s.days.length - _range)),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(color: _readColor, label: 'Đọc'),
                  SizedBox(width: 16),
                  _Legend(color: _listenColor, label: 'Nghe'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Theo truyện (30 ngày)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _PerBook(perBook: s.perBook30),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _readColor = Color(0xFF0D9488);
const Color _listenColor = Color(0xFFF59E0B);

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.local_fire_department,
          color: Color(0xFFEA580C),
          size: 36,
        ),
        title: Text(
          streak == 0 ? 'Chưa có chuỗi ngày đọc' : '$streak ngày liên tiếp',
        ),
        subtitle: const Text('Số ngày liên tiếp có đọc hoặc nghe truyện'),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.label, required this.totals});

  final String label;
  final StatTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelLarge),
            const SizedBox(height: 6),
            Text('Đọc', style: t.bodySmall),
            Text(Fmt.duration(totals.readSeconds), style: t.titleSmall),
            const SizedBox(height: 4),
            Text('Nghe', style: t.bodySmall),
            Text(Fmt.duration(totals.listenSeconds), style: t.titleSmall),
            const SizedBox(height: 4),
            Text('${totals.chaptersFinished} chương xong', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _DayChart extends StatelessWidget {
  const _DayChart({required this.days});

  final List<DayPoint> days;

  @override
  Widget build(BuildContext context) {
    double maxMin = 10;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final r = days[i].totals.readSeconds / 60.0;
      final l = days[i].totals.listenSeconds / 60.0;
      if (r + l > maxMin) maxMin = r + l;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: r + l,
              width: days.length > 10 ? 6 : 18,
              borderRadius: BorderRadius.circular(3),
              color: _readColor,
              rodStackItems: [
                BarChartRodStackItem(0, r, _readColor),
                BarChartRodStackItem(r, r + l, _listenColor),
              ],
            ),
          ],
        ),
      );
    }
    final every = days.length > 10 ? 5 : 1;
    return BarChart(
      BarChartData(
        maxY: maxMin * 1.15,
        barGroups: groups,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) {
              final d = days[group.x];
              return BarTooltipItem(
                '${d.date.day}/${d.date.month}\nĐọc ${Fmt.duration(d.totals.readSeconds)}\nNghe ${Fmt.duration(d.totals.listenSeconds)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      '${v.round()}\'',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 ||
                    i >= days.length ||
                    (days.length - 1 - i) % every != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${days[i].date.day}/${days[i].date.month}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PerBook extends ConsumerWidget {
  const _PerBook({required this.perBook});

  final Map<int, StatTotals> perBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider).value ?? const [];
    final entries =
        perBook.entries.where((e) => e.value.totalSeconds > 0).toList()..sort(
          (a, b) => b.value.totalSeconds.compareTo(a.value.totalSeconds),
        );
    if (entries.isEmpty) return const Text('Chưa có dữ liệu.');
    return Column(
      children: [
        for (final e in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              books
                      .where((b) => b.id == e.key)
                      .map((b) => b.displayTitle)
                      .firstOrNull ??
                  'Truyện đã xóa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Đọc ${Fmt.duration(e.value.readSeconds)} · Nghe ${Fmt.duration(e.value.listenSeconds)}',
            ),
          ),
      ],
    );
  }
}
