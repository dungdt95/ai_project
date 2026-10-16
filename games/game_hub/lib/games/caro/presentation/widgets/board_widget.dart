import 'dart:math';

import 'package:flutter/material.dart';
import '../../domain/board.dart';
import '../../domain/move.dart';
import 'stone_widget.dart';

/// Interactive 15×15 Caro board with pinch-zoom and pan support.
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.board,
    required this.onTap,
    this.hintPosition,
    this.enabled = true,
  });

  final Board board;
  final void Function(Position pos) onTap;
  final Position? hintPosition;
  final bool enabled;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 0.6,
      maxScale: 3.0,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _BoardPainter(
            board: widget.board,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: _TapLayer(
            board: widget.board,
            onTap: widget.enabled ? widget.onTap : (_) {},
            hintPosition: widget.hintPosition,
          ),
        ),
      ),
    );
  }
}

class _TapLayer extends StatelessWidget {
  const _TapLayer({
    required this.board,
    required this.onTap,
    this.hintPosition,
  });

  final Board board;
  final void Function(Position) onTap;
  final Position? hintPosition;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = side / board.size;
        return Stack(
          children: [
            // Tap targets.
            for (int r = 0; r < board.size; r++)
              for (int c = 0; c < board.size; c++)
                Positioned(
                  left: c * cellSize,
                  top: r * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: GestureDetector(
                    onTap: () => onTap(Position(r, c)),
                    child: board.cells[r][c] != null
                        ? Center(
                            child: StoneWidget(
                              player: board.cells[r][c]!,
                              size: cellSize * 0.75,
                            ),
                          )
                        : hintPosition == Position(r, c)
                            ? Center(
                                child: Container(
                                  width: cellSize * 0.4,
                                  height: cellSize * 0.4,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                  ),
                ),

            // Winning line highlight.
            if (board.winningLine != null)
              ...board.winningLine!.map(
                (pos) => Positioned(
                  left: pos.col * cellSize + cellSize * 0.1,
                  top: pos.row * cellSize + cellSize * 0.1,
                  width: cellSize * 0.8,
                  height: cellSize * 0.8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            // Last move indicator.
            if (board.history.isNotEmpty && board.winningLine == null)
              Builder(builder: (context) {
                final last = board.history.last.position;
                return Positioned(
                  left: last.col * cellSize + cellSize * 0.3,
                  top: last.row * cellSize + cellSize * 0.3,
                  width: cellSize * 0.4,
                  height: cellSize * 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.board, required this.isDark});
  final Board board;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isDark ? const Color(0xFF2E3A2E) : const Color(0xFFF5DEB3);
    final lineColor = isDark ? Colors.grey.shade600 : Colors.brown.shade600;

    final n = board.size;
    // Always treat the board as a square using the shorter side so that any
    // extra canvas area below (when height > width) is left transparent and
    // the scaffold background shows through instead of the board color.
    final side = size.shortestSide;
    final cellSize = side / n;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..color = bgColor,
    );

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    for (int i = 0; i <= n; i++) {
      final pos = cellSize * i;
      canvas.drawLine(Offset(pos, 0), Offset(pos, side), linePaint);
      canvas.drawLine(Offset(0, pos), Offset(side, pos), linePaint);
    }

    final mid = n ~/ 2;
    canvas.drawCircle(
      Offset(mid * cellSize + cellSize / 2, mid * cellSize + cellSize / 2),
      3,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.isDark != isDark;
}
