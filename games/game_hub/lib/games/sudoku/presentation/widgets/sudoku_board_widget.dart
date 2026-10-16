import 'package:flutter/material.dart';
import '../../domain/rules.dart';
import '../../domain/sudoku_board.dart';
import '../../domain/sudoku_pos.dart';
import '../../domain/variant.dart';
import 'cage_painter.dart';
import 'sudoku_cell_widget.dart';

class SudokuBoardWidget extends StatelessWidget {
  const SudokuBoardWidget({
    super.key,
    required this.board,
    required this.selectedPos,
    required this.errorCells,
    required this.hintPos,
    required this.onCellTap,
  });

  final SudokuBoard board;
  final SudokuPos? selectedPos;
  final Set<SudokuPos> errorCells;
  final SudokuPos? hintPos;
  final void Function(int row, int col) onCellTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / 9;
          return Stack(
            children: [
              // Grid
              Column(
                children: List.generate(9, (r) => Expanded(
                  child: Row(
                    children: List.generate(9, (c) => Expanded(
                      child: _buildCell(context, r, c),
                    )),
                  ),
                )),
              ),
              // Box borders (drawn on top)
              CustomPaint(
                painter: _BoxBorderPainter(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
              // Killer cage overlay
              if (board.variant == SudokuVariant.killer && board.cages != null)
                CustomPaint(
                  painter: CagePainter(
                    cages: board.cages!,
                    cellSize: cellSize,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCell(BuildContext context, int row, int col) {
    final pos = SudokuPos(row, col);
    final cell = board.cellAt(row, col);
    final highlight = _highlight(pos);
    return SudokuCellWidget(
      cell: cell,
      highlight: highlight,
      onTap: () => onCellTap(row, col),
    );
  }

  CellHighlight _highlight(SudokuPos pos) {
    if (hintPos != null && hintPos == pos) return CellHighlight.hint;
    if (errorCells.contains(pos)) return CellHighlight.error;

    if (selectedPos == null) {
      if (board.variant == SudokuVariant.xSudoku &&
          SudokuRules.isOnDiagonal(pos.row, pos.col)) {
        return CellHighlight.diagonal;
      }
      return CellHighlight.none;
    }

    final sel = selectedPos!;
    if (pos == sel) return CellHighlight.selected;

    // Same value highlight
    final selVal = board.cellAt(sel.row, sel.col).value;
    if (selVal != null && board.cellAt(pos.row, pos.col).value == selVal) {
      return CellHighlight.sameValue;
    }

    // Peer highlight
    final peers = SudokuRules.peersOf(sel.row, sel.col, board.variant, board.cages);
    if (peers.contains(pos)) return CellHighlight.peer;

    // X-Sudoku diagonal background
    if (board.variant == SudokuVariant.xSudoku &&
        SudokuRules.isOnDiagonal(pos.row, pos.col)) {
      return CellHighlight.diagonal;
    }

    return CellHighlight.none;
  }
}

class _BoxBorderPainter extends CustomPainter {
  const _BoxBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final cell = size.width / 9;
    for (int i = 0; i <= 3; i++) {
      final x = i * 3 * cell;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, x), Offset(size.width, x), paint);
    }
  }

  @override
  bool shouldRepaint(_BoxBorderPainter old) => old.color != color;
}
