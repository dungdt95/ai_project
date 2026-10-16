import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/bida_stats_service.dart';
import '../domain/variant.dart';

class BidaMenuScreen extends StatefulWidget {
  const BidaMenuScreen({super.key});

  @override
  State<BidaMenuScreen> createState() => _BidaMenuScreenState();
}

class _BidaMenuScreenState extends State<BidaMenuScreen> {
  BidaVariant _variant = BidaVariant.eightBall;
  BidaMode _mode = BidaMode.vsHuman;
  AiLevel _aiLevel = AiLevel.medium;

  bool get _dailyCompleted => BidaStatsService.instance.dailyCompleted;

  @override
  Widget build(BuildContext context) {
    final canStartDaily = _mode != BidaMode.daily || !_dailyCompleted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bida'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Thống kê',
            onPressed: () => context.push('/bida/stats'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily challenge banner
          if (_mode == BidaMode.daily) _DailyBanner(completed: _dailyCompleted),
          _SectionTitle('Loại game'),
          const SizedBox(height: 8),
          // Carom + daily don't mix (carom has no pockets, daily is 8-ball)
          ...BidaVariant.values.map((v) => _VariantCard(
                variant: v,
                selected: _variant == v,
                onTap: (_mode == BidaMode.daily && v != BidaVariant.eightBall)
                    ? null
                    : () => setState(() => _variant = v),
              )),
          const SizedBox(height: 8),
          const Divider(),
          _SectionTitle('Chế độ'),
          ...BidaMode.values.map((m) => RadioListTile<BidaMode>(
                title: Text(_modeLabel(m)),
                subtitle: _modeSubtitle(m),
                value: m,
                groupValue: _mode,
                onChanged: (val) => setState(() {
                  _mode = val!;
                  if (_mode == BidaMode.daily) _variant = BidaVariant.eightBall;
                }),
                dense: true,
              )),
          if (_mode == BidaMode.vsAi) ...[
            const Divider(),
            _SectionTitle('Độ khó AI'),
            ...AiLevel.values.map((l) => RadioListTile<AiLevel>(
                  title: Text(_aiLabel(l)),
                  subtitle: Text(_aiDesc(l)),
                  value: l,
                  groupValue: _aiLevel,
                  onChanged: (val) => setState(() => _aiLevel = val!),
                  dense: true,
                )),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: canStartDaily ? _startGame : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Bắt đầu', style: TextStyle(fontSize: 16)),
            ),
          ),
          if (_mode == BidaMode.daily && _dailyCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Bạn đã hoàn thành daily hôm nay!',
                  style: TextStyle(color: Colors.green.shade400, fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _startGame() {
    context.push('/bida/play', extra: {
      'variant': _variant,
      'mode': _mode,
      'aiLevel': _mode == BidaMode.vsAi ? _aiLevel : null,
    });
  }

  String _modeLabel(BidaMode m) {
    switch (m) {
      case BidaMode.vsAi:     return 'vs AI';
      case BidaMode.vsHuman:  return 'vs Người (hot-seat)';
      case BidaMode.practice: return 'Luyện tập';
      case BidaMode.daily:    return 'Daily Challenge';
    }
  }

  Widget? _modeSubtitle(BidaMode m) {
    switch (m) {
      case BidaMode.practice:
        return const Text('Tự do đánh, không luật, không đổi lượt',
            style: TextStyle(fontSize: 11));
      case BidaMode.daily:
        return const Text('Bàn đặc biệt mỗi ngày — 8-ball',
            style: TextStyle(fontSize: 11));
      default:
        return null;
    }
  }

  String _aiLabel(AiLevel l) {
    switch (l) {
      case AiLevel.easy:   return 'Dễ';
      case AiLevel.medium: return 'Trung bình';
      case AiLevel.hard:   return 'Khó';
    }
  }

  String _aiDesc(AiLevel l) {
    switch (l) {
      case AiLevel.easy:   return 'Đánh ngẫu nhiên, nhiều lỗi';
      case AiLevel.medium: return 'Chọn cú tốt nhất, ít lỗi';
      case AiLevel.hard:   return 'Tính toán chính xác, rất khó';
    }
  }
}

// ── Daily banner ──────────────────────────────────────────────────────────────

class _DailyBanner extends StatelessWidget {
  const _DailyBanner({required this.completed});
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return Card(
      color: completed ? Colors.green.shade900.withOpacity(0.3) : Colors.blue.shade900.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(completed ? Icons.check_circle : Icons.today,
                color: completed ? Colors.green : Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Challenge – $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    completed ? 'Đã hoàn thành hôm nay!' : 'Bàn bida đặc biệt — chỉ 1 lần mỗi ngày',
                    style: TextStyle(
                      fontSize: 11,
                      color: completed ? Colors.green.shade300 : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Variant card ──────────────────────────────────────────────────────────────

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final BidaVariant variant;
  final bool selected;
  final VoidCallback? onTap;

  String get _description {
    switch (variant) {
      case BidaVariant.eightBall:
        return '15 bi, chia solid/stripe. Hạ bi 8 để thắng.';
      case BidaVariant.nineBall:
        return '9 bi xếp kim cương. Phải đánh bi thấp nhất trước. Hạ bi 9 để thắng.';
      case BidaVariant.vnBall:
        return '10 bi xếp tam giác. Xoay vòng — đánh bi thấp nhất trước. Hạ bi 10 để thắng.';
      case BidaVariant.carom:
        return 'Carom 3 băng không lỗ. 3 bi, cần chạm 3 băng trước khi chạm bi 2.';
    }
  }

  String get _balls {
    switch (variant) {
      case BidaVariant.eightBall: return '15 bi';
      case BidaVariant.nineBall:  return '9 bi';
      case BidaVariant.vnBall:    return '10 bi';
      case BidaVariant.carom:     return '3 bi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Radio<BidaVariant>(
                  value: variant,
                  groupValue: selected ? variant : BidaVariant.eightBall,
                  onChanged: isDisabled ? null : (_) => onTap?.call(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(variant.displayName,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_balls, style: theme.textTheme.labelSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}
