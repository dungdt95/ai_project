import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/variant.dart';
import 'sudoku_game_notifier.dart';
import 'sudoku_settings_notifier.dart';
import 'widgets/action_bar.dart';
import 'widgets/number_pad.dart';
import 'widgets/sudoku_board_widget.dart';
import 'widgets/timer_widget.dart';

class SudokuGameScreen extends ConsumerWidget {
  const SudokuGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sudokuGameProvider);
    final settings = ref.watch(sudokuSettingsProvider);

    // Show achievement toasts
    ref.listen(sudokuGameProvider, (prev, next) {
      if (next.newAchievements.isNotEmpty &&
          (prev == null || prev.newAchievements != next.newAchievements)) {
        for (final a in next.newAchievements) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏆 ${a.title}: ${a.description}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        ref.read(sudokuGameProvider.notifier).clearNewAchievements();
      }
    });

    if (state.isGenerating || state.board == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sudoku')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final board = state.board!;
    final notifier = ref.read(sudokuGameProvider.notifier);

    // Show completion dialog once.
    if (state.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompleteDialog(context, state, board.variant);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${board.variant.label} — ${board.difficulty.label}'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TimerWidget(elapsed: state.elapsed),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Board
              Expanded(
                child: Center(
                  child: SudokuBoardWidget(
                    board: board,
                    selectedPos: state.selectedPos,
                    errorCells: state.errorCells,
                    hintPos: state.hintPos,
                    onCellTap: notifier.selectCell,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Action bar
              ActionBar(
                canUndo: state.canUndo,
                canRedo: state.canRedo,
                canHint: state.canHint,
                hintsUsed: state.hintsUsed,
                notesMode: settings.notesMode,
                onUndo: notifier.undo,
                onRedo: notifier.redo,
                onHint: () => notifier.requestHint(),
                onToggleNotes: () =>
                    ref.read(sudokuSettingsProvider.notifier).toggleNotes(),
                onErase: notifier.erase,
              ),
              const SizedBox(height: 8),
              // Number pad
              NumberPad(
                placed: board.countPlaced(),
                notesMode: settings.notesMode,
                onNumber: (v) => notifier.placeValue(v),
                onErase: notifier.erase,
                onToggleNotes: () =>
                    ref.read(sudokuSettingsProvider.notifier).toggleNotes(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteDialog(
    BuildContext context,
    SudokuGameState state,
    SudokuVariant variant,
  ) {
    if (!context.mounted) return;
    final elapsed = state.elapsed;
    final min = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Hoàn thành! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thời gian: $min:$sec'),
            Text('Lỗi: ${state.mistakeCount}'),
            Text('Gợi ý đã dùng: ${state.hintsUsed}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Về menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // The notifier keeps the same variant/difficulty preferences;
              // re-navigate to menu to start a new game.
              context.pop();
            },
            child: const Text('Ván mới'),
          ),
        ],
      ),
    );
  }
}
