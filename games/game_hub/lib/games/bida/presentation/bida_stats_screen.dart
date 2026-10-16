import 'package:flutter/material.dart';
import '../data/bida_stats_service.dart';
import '../domain/variant.dart';

class BidaStatsScreen extends StatefulWidget {
  const BidaStatsScreen({super.key});

  @override
  State<BidaStatsScreen> createState() => _BidaStatsScreenState();
}

class _BidaStatsScreenState extends State<BidaStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bida – Thống kê & Thành tích'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Thống kê'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Thành tích'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _StatsTab(),
          _AchievementsTab(),
        ],
      ),
    );
  }
}

// ── Stats tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    final svc = BidaStatsService.instance;
    final total = svc.totalStats();
    final daily = svc.todayResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily challenge card
        _DailyCard(result: daily),
        const SizedBox(height: 12),
        const Divider(),
        _SectionTitle('Tổng quát'),
        _StatTile(icon: Icons.sports_esports, label: 'Tổng ván', value: '${total.totalGames}'),
        _StatTile(icon: Icons.emoji_events, label: 'Tổng thắng', value: '${total.totalWins}',
            color: Colors.green),
        _StatTile(icon: Icons.sports_cricket, label: 'Tổng cú đánh', value: '${total.totalShots}'),
        _StatTile(icon: Icons.warning_amber, label: 'Tổng phạm quy', value: '${total.totalFouls}',
            color: total.totalFouls > 0 ? Colors.orange : null),
        const Divider(height: 24),
        _SectionTitle('Theo loại game'),
        ...BidaVariant.values
            .where((v) => v.hasPockets)
            .map((v) => _VariantStatCard(stats: svc.statsFor(v))),
        _VariantStatCard(stats: svc.statsFor(BidaVariant.carom)),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.result});
  final DailyResult? result;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return Card(
      color: result != null
          ? Colors.green.shade800.withOpacity(0.15)
          : Colors.blue.shade800.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              result != null ? Icons.check_circle : Icons.today,
              color: result != null ? Colors.green : Colors.blue,
              size: 36,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Challenge – $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (result != null)
                    Text(
                      'Hoàn thành: ${result!.shots} cú • ${result!.fouls} phạm quy',
                      style: TextStyle(color: Colors.green.shade300, fontSize: 13),
                    )
                  else
                    const Text('Chưa chơi hôm nay',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantStatCard extends StatelessWidget {
  const _VariantStatCard({required this.stats});
  final BidaVariantStats stats;

  @override
  Widget build(BuildContext context) {
    final pct = stats.games == 0 ? '—' : '${(stats.winRate * 100).round()}%';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.variant.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    stats.games == 0
                        ? 'Chưa chơi ván nào'
                        : '${stats.wins}T / ${stats.losses}T  •  ${stats.games} ván',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (stats.bestShotWin > 0)
                    Text('Best: ${stats.bestShotWin} cú',
                        style: const TextStyle(fontSize: 11, color: Colors.amber)),
                ],
              ),
            ),
            Text(
              pct,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: stats.winRate >= 0.5 ? Colors.green : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label),
      trailing: Text(value,
          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

// ── Achievements tab ──────────────────────────────────────────────────────────

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();

  static const _all = [
    _AchDef('first_win',           'Chiến thắng đầu tiên', 'Thắng 1 ván bất kỳ',      Icons.star),
    _AchDef('wins_10',             'Bậc thầy mới vào',    'Thắng 10 ván',             Icons.workspace_premium),
    _AchDef('wins_50',             'Cao thủ bida',         'Thắng 50 ván',             Icons.military_tech),
    _AchDef('beat_hard_ai',        'Thắng AI khó',         'Thắng AI ở độ khó Khó',   Icons.smart_toy),
    _AchDef('no_foul_win',         'Sạch như gương',       'Thắng ván không phạm quy', Icons.cleaning_services),
    _AchDef('quick_win_9ball',     'Tốc chiến',            'Thắng 9-ball trong ≤12 cú',Icons.bolt),
    _AchDef('all_pocket_variants', 'Toàn năng',            'Thắng cả 3 loại pool',     Icons.collections_bookmark),
  ];

  @override
  Widget build(BuildContext context) {
    final unlocked = BidaStatsService.instance.unlockedAchievements;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = _all[i];
        final done = unlocked.contains(a.id);
        return _AchievementTile(def: a, unlocked: done);
      },
    );
  }
}

class _AchDef {
  const _AchDef(this.id, this.title, this.desc, this.icon);
  final String id;
  final String title;
  final String desc;
  final IconData icon;
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.def, required this.unlocked});
  final _AchDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.4,
      child: Card(
        color: unlocked
            ? Colors.amber.shade900.withOpacity(0.15)
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: unlocked ? Colors.amber.shade700 : Colors.grey.shade700,
            child: Icon(def.icon, color: Colors.white, size: 20),
          ),
          title: Text(def.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(def.desc, style: const TextStyle(fontSize: 12)),
          trailing: unlocked
              ? const Icon(Icons.check_circle, color: Colors.amber)
              : const Icon(Icons.lock_outline, color: Colors.white24),
        ),
      ),
    );
  }
}
