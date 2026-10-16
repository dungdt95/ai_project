import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/caro_history_service.dart';
import 'caro_game_notifier.dart';

class CaroHistoryScreen extends ConsumerWidget {
  const CaroHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.read(caroGameProvider.notifier).getHistory();

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử ván đấu')),
      body: records.isEmpty
          ? const Center(child: Text('Chưa có ván đấu nào'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, i) => _RecordTile(record: records[i]),
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final resultText = switch (record.result) {
      GameResult.win => 'Thắng',
      GameResult.lose => 'Thua',
      GameResult.draw => 'Hoà',
      GameResult.resign => 'Đầu hàng',
    };
    final resultColor = switch (record.result) {
      GameResult.win => Colors.green,
      GameResult.lose => Colors.red,
      GameResult.draw => Colors.orange,
      GameResult.resign => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: resultColor.withOpacity(0.15),
        child: Text(resultText[0],
            style: TextStyle(color: resultColor, fontWeight: FontWeight.bold)),
      ),
      title: Text('${record.mode.label} — $resultText'),
      subtitle: Text(
        '${record.moves.length} nước · ${_formatDuration(record.duration)} · ${_formatDate(record.startedAt)}',
      ),
      trailing: const Icon(Icons.play_circle_outline),
      onTap: () => context.push('/caro/replay', extra: record),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m${s}s';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class CaroReplayScreen extends StatefulWidget {
  const CaroReplayScreen({super.key, required this.record});
  final GameRecord record;

  @override
  State<CaroReplayScreen> createState() => _CaroReplayScreenState();
}

class _CaroReplayScreenState extends State<CaroReplayScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final moves = widget.record.moves;
    final total = moves.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Xem lại ván đấu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Nước ${ _step} / $total'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _ReplayBoard(moves: moves.sublist(0, _step)),
            ),
          ),
          _ReplayControls(
            step: _step,
            total: total,
            onFirst: () => setState(() => _step = 0),
            onPrev: () => setState(() => _step = (_step - 1).clamp(0, total)),
            onNext: () => setState(() => _step = (_step + 1).clamp(0, total)),
            onLast: () => setState(() => _step = total),
          ),
        ],
      ),
    );
  }
}

class _ReplayBoard extends StatelessWidget {
  const _ReplayBoard({required this.moves});
  final List moves;

  @override
  Widget build(BuildContext context) {
    const size = 15;
    final cells = List.generate(size, (_) => List.filled(size, null as dynamic));
    for (final m in moves) {
      cells[m.position.row][m.position.col] = m.player;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _SimpleBoardPainter(
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final cellSize = constraints.maxWidth / size;
          return Stack(
            children: [
              for (int r = 0; r < size; r++)
                for (int c = 0; c < size; c++)
                  if (cells[r][c] != null)
                    Positioned(
                      left: c * cellSize + cellSize * 0.125,
                      top: r * cellSize + cellSize * 0.125,
                      width: cellSize * 0.75,
                      height: cellSize * 0.75,
                      child: _StoneCircle(player: cells[r][c]),
                    ),
            ],
          );
        }),
      ),
    );
  }
}

class _StoneCircle extends StatelessWidget {
  const _StoneCircle({required this.player});
  final dynamic player;

  @override
  Widget build(BuildContext context) {
    final color = player.label == 'X'
        ? const Color(0xFFC62828)
        : const Color(0xFF1565C0);
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(player.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }
}

class _SimpleBoardPainter extends CustomPainter {
  const _SimpleBoardPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 15;
    final bg = isDark ? const Color(0xFF2E3A2E) : const Color(0xFFF5DEB3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = bg);
    final cell = size.width / n;
    final paint = Paint()
      ..color = isDark ? Colors.grey.shade600 : Colors.brown.shade600
      ..strokeWidth = 0.8;
    for (int i = 0; i < n; i++) {
      final v = cell * i + cell / 2;
      canvas.drawLine(Offset(v, cell / 2), Offset(v, size.height - cell / 2), paint);
      canvas.drawLine(Offset(cell / 2, v), Offset(size.width - cell / 2, v), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ReplayControls extends StatelessWidget {
  const _ReplayControls({
    required this.step,
    required this.total,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  final int step, total;
  final VoidCallback onFirst, onPrev, onNext, onLast;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.skip_previous), onPressed: step > 0 ? onFirst : null),
            IconButton(icon: const Icon(Icons.navigate_before), onPressed: step > 0 ? onPrev : null),
            IconButton(icon: const Icon(Icons.navigate_next), onPressed: step < total ? onNext : null),
            IconButton(icon: const Icon(Icons.skip_next), onPressed: step < total ? onLast : null),
          ],
        ),
      ),
    );
  }
}
