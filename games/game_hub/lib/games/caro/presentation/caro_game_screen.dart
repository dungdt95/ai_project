import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/caro_history_service.dart';
import '../domain/board.dart';
import '../domain/move.dart';
import 'caro_game_notifier.dart';
import 'widgets/board_widget.dart';

class CaroGameScreen extends ConsumerStatefulWidget {
  const CaroGameScreen({super.key});

  @override
  ConsumerState<CaroGameScreen> createState() => _CaroGameScreenState();
}

class _CaroGameScreenState extends ConsumerState<CaroGameScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(caroGameProvider);
    final notifier = ref.read(caroGameProvider.notifier);
    final board = state.board;

    // Show result dialog when game ends.
    ref.listen(caroGameProvider, (prev, next) {
      if (prev?.board.status == GameStatus.playing &&
          next.board.status != GameStatus.playing) {
        Future.microtask(() => _showResultDialog(context, next, notifier));
      }
    });

    final isHumanTurn = state.mode == GameMode.vsHumanLocal ||
        state.mode == GameMode.vsHumanLan ||
        board.currentTurn == state.humanSide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cờ Caro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Đầu hàng',
            onPressed: board.isOver
                ? null
                : () => _confirmResign(context, notifier),
          ),
        ],
      ),
      body: Column(
        children: [
          _PlayerBar(
            xName: state.playerXName,
            oName: state.playerOName,
            activeTurn: board.currentTurn,
            isThinking: state.isThinking,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BoardWidget(
                board: board,
                hintPosition: state.hintPosition,
                enabled: isHumanTurn && !board.isOver && !state.isThinking,
                onTap: (pos) => notifier.placeStone(pos),
              ),
            ),
          ),
          _ActionBar(state: state, notifier: notifier),
        ],
      ),
    );
  }

  void _confirmResign(BuildContext context, CaroGameNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đầu hàng?'),
        content: const Text('Bạn có chắc muốn đầu hàng ván này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Không')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resign();
            },
            child: const Text('Đầu hàng'),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(
    BuildContext context,
    CaroGameState state,
    CaroGameNotifier notifier,
  ) {
    if (!context.mounted) return;
    final board = state.board;
    final String title;

    switch (board.status) {
      case GameStatus.xWon:
        title = '${state.playerXName} thắng! 🎉';
      case GameStatus.oWon:
        title = '${state.playerOName} thắng! 🎉';
      case GameStatus.draw:
        title = 'Hoà!';
      default:
        return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Về menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.newGame();
            },
            child: const Text('Chơi lại'),
          ),
        ],
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.xName,
    required this.oName,
    required this.activeTurn,
    required this.isThinking,
  });

  final String xName;
  final String oName;
  final Player activeTurn;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.surfaceVariant,
      child: Row(
        children: [
          _PlayerChip(
            name: xName,
            label: 'X',
            color: const Color(0xFFC62828),
            isActive: activeTurn == Player.x,
          ),
          const Spacer(),
          if (isThinking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const Spacer(),
          _PlayerChip(
            name: oName,
            label: 'O',
            color: const Color(0xFF1565C0),
            isActive: activeTurn == Player.o,
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.name,
    required this.label,
    required this.color,
    required this.isActive,
  });

  final String name;
  final String label;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.state, required this.notifier});

  final CaroGameState state;
  final CaroGameNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = state.board;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionBtn(
              icon: Icons.undo,
              label: 'Đi lại\n(${CaroGameState.maxUndos - state.undoUsed})',
              enabled: state.canUndo,
              onTap: notifier.undo,
            ),
            _ActionBtn(
              icon: Icons.lightbulb_outline,
              label: 'Gợi ý\n(${CaroGameState.maxHints - state.hintUsed})',
              enabled: state.canHint && !state.isThinking,
              onTap: () => notifier.requestHint(),
            ),
            _ActionBtn(
              icon: Icons.refresh,
              label: 'Ván mới',
              enabled: true,
              onTap: () {
                if (board.isOver || board.history.isEmpty) {
                  notifier.newGame();
                } else {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Ván mới?'),
                      content: const Text('Bỏ ván hiện tại và bắt đầu ván mới?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Huỷ'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            notifier.newGame();
                          },
                          child: const Text('Mới'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
