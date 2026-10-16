import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/sudoku_save_service.dart';
import '../domain/variant.dart';
import 'sudoku_game_notifier.dart';

class SudokuMenuScreen extends ConsumerWidget {
  const SudokuMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push('/sudoku/stats'),
            tooltip: 'Thống kê',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/sudoku/history'),
            tooltip: 'Lịch sử',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily puzzle banner
          _DailyCard(
            onTap: () => _startGame(
              context,
              ref,
              variant: SudokuVariant.classic,
              difficulty: SudokuDifficulty.medium,
              isDaily: true,
            ),
          ),
          const SizedBox(height: 16),
          // Continue buttons
          for (final v in SudokuVariant.values)
            if (SudokuSaveService.instance.hasSave(v)) ...[
              _ContinueCard(
                variant: v,
                onTap: () => _continue(context, ref, v),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          // Variant cards
          for (final variant in SudokuVariant.values) ...[
            _VariantCard(
              variant: variant,
              onStart: (difficulty) => _startGame(
                context,
                ref,
                variant: variant,
                difficulty: difficulty,
                isDaily: false,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _startGame(
    BuildContext context,
    WidgetRef ref, {
    required SudokuVariant variant,
    required SudokuDifficulty difficulty,
    required bool isDaily,
  }) async {
    await ref.read(sudokuGameProvider.notifier).startNew(
          variant: variant,
          difficulty: difficulty,
          isDaily: isDaily,
        );
    if (context.mounted) context.push('/sudoku/game');
  }

  Future<void> _continue(
    BuildContext context,
    WidgetRef ref,
    SudokuVariant variant,
  ) async {
    await ref.read(sudokuGameProvider.notifier).resume(variant);
    if (context.mounted) context.push('/sudoku/game');
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.today, color: cs.onPrimaryContainer, size: 32),
        title: Text(
          'Puzzle Hàng Ngày',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cs.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          'Cùng puzzle cho mọi người',
          style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.8)),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: cs.onPrimaryContainer),
        onTap: onTap,
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.variant, required this.onTap});
  final SudokuVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text('Tiếp tục ${variant.label}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant, required this.onStart});
  final SudokuVariant variant;
  final void Function(SudokuDifficulty) onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_variantIcon(), color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variant.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                    Text(variant.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.outline)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: SudokuDifficulty.values
                  .map((d) => ActionChip(
                        label: Text(d.label),
                        onPressed: () => onStart(d),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _variantIcon() => switch (variant) {
        SudokuVariant.classic => Icons.grid_on,
        SudokuVariant.killer => Icons.calculate_outlined,
        SudokuVariant.xSudoku => Icons.close,
      };
}
