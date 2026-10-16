import 'package:flutter/material.dart';
import '../../domain/cell.dart';

enum CellHighlight { none, selected, peer, sameValue, error, hint, diagonal }

class SudokuCellWidget extends StatelessWidget {
  const SudokuCellWidget({
    super.key,
    required this.cell,
    required this.highlight,
    required this.onTap,
  });

  final Cell cell;
  final CellHighlight highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    switch (highlight) {
      case CellHighlight.selected:
        bg = cs.primary.withOpacity(0.7);
      case CellHighlight.hint:
        bg = Colors.orange.withOpacity(0.6);
      case CellHighlight.error:
        bg = Colors.red.withOpacity(isDark ? 0.4 : 0.25);
      case CellHighlight.sameValue:
        bg = cs.primaryContainer.withOpacity(isDark ? 0.5 : 0.4);
      case CellHighlight.peer:
        bg = cs.surfaceVariant.withOpacity(isDark ? 0.4 : 0.5);
      case CellHighlight.diagonal:
        bg = cs.secondaryContainer.withOpacity(0.25);
      case CellHighlight.none:
        bg = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: cs.outline.withOpacity(0.3), width: 0.5),
        ),
        alignment: Alignment.center,
        child: _content(context, cs),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme cs) {
    if (cell.value != null) {
      return Text(
        '${cell.value}',
        style: TextStyle(
          fontSize: 20,
          fontWeight: cell.isGiven ? FontWeight.bold : FontWeight.normal,
          color: cell.isGiven
              ? cs.onSurface
              : highlight == CellHighlight.error
                  ? Colors.red.shade700
                  : cs.primary,
        ),
      );
    }

    if (cell.notes.isNotEmpty) {
      return _NotesGrid(notes: cell.notes);
    }

    return const SizedBox.shrink();
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.notes});
  final Set<int> notes;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(1),
      children: List.generate(9, (i) {
        final n = i + 1;
        return Center(
          child: Text(
            notes.contains(n) ? '$n' : '',
            style: TextStyle(
              fontSize: 8,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        );
      }),
    );
  }
}
