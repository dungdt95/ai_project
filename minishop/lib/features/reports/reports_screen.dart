import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import 'report_range.dart';
import 'reports_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRangeChips(controller),
                  const SizedBox(height: 16),
                  _buildSummary(controller),
                  const SizedBox(height: 24),
                  Text('Doanh thu theo ngày',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildChart(controller),
                  const SizedBox(height: 24),
                  Text('Top mặt hàng',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildTopItems(controller),
                ],
              ),
            ),
    );
  }

  Widget _buildRangeChips(ReportsController controller) {
    return Wrap(
      spacing: 8,
      children: ReportRange.values.map((range) {
        return ChoiceChip(
          label: Text(range.label),
          selected: controller.range == range,
          onSelected: (_) => controller.setRange(range),
        );
      }).toList(),
    );
  }

  Widget _buildSummary(ReportsController controller) {
    final counts = controller.counts;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng doanh thu', style: TextStyle(color: Colors.grey)),
            Text(
              formatVnd(controller.totalRevenue),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _countBadge('Đã TT', counts.paid, Colors.green),
                const SizedBox(width: 12),
                _countBadge('Chưa TT', counts.unpaid, Colors.orange),
                const SizedBox(width: 12),
                _countBadge('Đã hủy', counts.cancelled, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildChart(ReportsController controller) {
    final series = controller.revenueSeries;
    if (series.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
            child: Text('Chưa có doanh thu trong khoảng thời gian này.')),
      );
    }

    final maxRevenue =
        series.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);
    final labelStep = (series.length / 7).ceil().clamp(1, series.length);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxRevenue == 0 ? 1 : maxRevenue * 1.2,
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].revenue.toDouble(),
                    color: Colors.teal,
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= series.length || i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('dd/MM').format(series[i].day),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  Widget _buildTopItems(ReportsController controller) {
    if (controller.topItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Chưa có dữ liệu bán hàng.'),
      );
    }
    return Column(
      children: controller.topItems.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('$rank')),
          title: Text(item.name),
          subtitle: Text('Đã bán ${item.quantity}'),
          trailing: Text(
            formatVnd(item.revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
