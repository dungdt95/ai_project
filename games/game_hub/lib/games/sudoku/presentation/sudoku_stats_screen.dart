import 'package:flutter/material.dart';
import '../data/achievement_service.dart';
import '../data/daily_streak_service.dart';
import '../data/sudoku_history_service.dart';
import '../domain/variant.dart';

class SudokuStatsScreen extends StatelessWidget {
  const SudokuStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = SudokuHistoryService.instance.computeStats();
    final streak = DailyStreakService.instance;
    final achievements = AchievementService.instance.unlocked;

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê Sudoku')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily streak
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
              title: Text(
                'Streak hiện tại: ${streak.currentStreak} ngày',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Dài nhất: ${streak.longestStreak} ngày'),
            ),
          ),
          const SizedBox(height: 16),

          // Grid per variant × difficulty
          Text('Số ván hoàn thành',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          _StatsTable(stats: stats),
          const SizedBox(height: 16),

          // Best times
          Text('Thời gian tốt nhất',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          _BestTimesTable(stats: stats),
          const SizedBox(height: 16),

          // Achievements
          Text('Thành tích (${achievements.length}/${SudokuAchievement.values.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          for (final a in SudokuAchievement.values)
            ListTile(
              dense: true,
              leading: Icon(
                achievements.contains(a) ? Icons.emoji_events : Icons.emoji_events_outlined,
                color: achievements.contains(a) ? Colors.amber : Colors.grey,
              ),
              title: Text(a.title),
              subtitle: Text(a.description),
            ),
        ],
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats});
  final SudokuStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Table(
      border: TableBorder.all(color: cs.outline.withOpacity(0.3)),
      children: [
        TableRow(
          decoration: BoxDecoration(color: cs.surfaceVariant),
          children: [
            const _TH(''),
            for (final d in SudokuDifficulty.values) _TH(d.label),
          ],
        ),
        for (final v in SudokuVariant.values)
          TableRow(
            children: [
              _TD(v.label, bold: true),
              for (final d in SudokuDifficulty.values)
                _TD('${stats.countFor(v, d)}'),
            ],
          ),
      ],
    );
  }
}

class _BestTimesTable extends StatelessWidget {
  const _BestTimesTable({required this.stats});
  final SudokuStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Table(
      border: TableBorder.all(color: cs.outline.withOpacity(0.3)),
      children: [
        TableRow(
          decoration: BoxDecoration(color: cs.surfaceVariant),
          children: [
            const _TH(''),
            for (final d in SudokuDifficulty.values) _TH(d.label),
          ],
        ),
        for (final v in SudokuVariant.values)
          TableRow(
            children: [
              _TD(v.label, bold: true),
              for (final d in SudokuDifficulty.values) _TD(_fmt(stats.bestTimeFor(v, d))),
            ],
          ),
      ],
    );
  }

  String _fmt(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TD extends StatelessWidget {
  const _TD(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
