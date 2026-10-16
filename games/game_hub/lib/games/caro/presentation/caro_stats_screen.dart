import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'caro_game_notifier.dart';

class CaroStatsScreen extends ConsumerWidget {
  const CaroStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.read(caroGameProvider.notifier).getStats();

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _StatCard(
            label: 'Tổng số ván',
            value: stats.total.toString(),
            icon: Icons.sports_esports,
          ),
          _StatCard(
            label: 'Thắng',
            value: stats.wins.toString(),
            icon: Icons.emoji_events,
            color: Colors.green,
          ),
          _StatCard(
            label: 'Thua',
            value: stats.losses.toString(),
            icon: Icons.sentiment_dissatisfied,
            color: Colors.red,
          ),
          _StatCard(
            label: 'Hoà',
            value: stats.draws.toString(),
            icon: Icons.handshake_outlined,
            color: Colors.orange,
          ),
          _StatCard(
            label: 'Tỉ lệ thắng',
            value: '${(stats.winRate * 100).toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: Colors.blue,
          ),
          _StatCard(
            label: 'Chuỗi hiện tại',
            value: '${stats.streak} ${stats.streakPositive ? '🔥' : ''}',
            icon: Icons.local_fire_department,
            color: stats.streakPositive ? Colors.deepOrange : Colors.grey,
          ),
          const SizedBox(height: 24),
          if (stats.total > 0)
            _WinRateBar(wins: stats.wins, losses: stats.losses, draws: stats.draws),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: effectiveColor, size: 32),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class _WinRateBar extends StatelessWidget {
  const _WinRateBar({
    required this.wins,
    required this.losses,
    required this.draws,
  });

  final int wins, losses, draws;

  @override
  Widget build(BuildContext context) {
    final total = wins + losses + draws;
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phân bố kết quả',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              if (wins > 0)
                Flexible(
                  flex: wins,
                  child: Container(
                    height: 20,
                    color: Colors.green,
                    alignment: Alignment.center,
                    child: Text('${(wins / total * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ),
              if (draws > 0)
                Flexible(
                  flex: draws,
                  child: Container(
                      height: 20,
                      color: Colors.orange,
                      alignment: Alignment.center,
                      child: Text('${(draws / total * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10))),
                ),
              if (losses > 0)
                Flexible(
                  flex: losses,
                  child: Container(
                    height: 20,
                    color: Colors.red,
                    alignment: Alignment.center,
                    child: Text('${(losses / total * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _Legend(color: Colors.green, label: 'Thắng'),
            const SizedBox(width: 12),
            _Legend(color: Colors.orange, label: 'Hoà'),
            const SizedBox(width: 12),
            _Legend(color: Colors.red, label: 'Thua'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
