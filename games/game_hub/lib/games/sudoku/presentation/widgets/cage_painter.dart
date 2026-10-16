import 'package:flutter/material.dart';
import '../../domain/killer_cage.dart';

/// Paints Killer Sudoku cage outlines (dashed) and sum labels.
class CagePainter extends CustomPainter {
  CagePainter({required this.cages, required this.cellSize});
  final List<KillerCage> cages;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black54;

    const dashLen = 4.0, gapLen = 3.0;

    for (final cage in cages) {
      final cellSet = {for (final p in cage.cells) '${p.row},${p.col}'};

      for (final pos in cage.cells) {
        final rx = pos.col * cellSize, ry = pos.row * cellSize;

        void drawEdge(double x1, double y1, double x2, double y2) {
          _drawDashed(canvas, Offset(x1, y1), Offset(x2, y2), paint, dashLen, gapLen);
        }

        // Top edge
        if (!cellSet.contains('${pos.row - 1},${pos.col}')) {
          drawEdge(rx + 2, ry + 2, rx + cellSize - 2, ry + 2);
        }
        // Bottom edge
        if (!cellSet.contains('${pos.row + 1},${pos.col}')) {
          drawEdge(rx + 2, ry + cellSize - 2, rx + cellSize - 2, ry + cellSize - 2);
        }
        // Left edge
        if (!cellSet.contains('${pos.row},${pos.col - 1}')) {
          drawEdge(rx + 2, ry + 2, rx + 2, ry + cellSize - 2);
        }
        // Right edge
        if (!cellSet.contains('${pos.row},${pos.col + 1}')) {
          drawEdge(rx + cellSize - 2, ry + 2, rx + cellSize - 2, ry + cellSize - 2);
        }
      }

      // Draw sum at top-left cell
      final topLeft = cage.cells.reduce((a, b) =>
          a.row < b.row || (a.row == b.row && a.col < b.col) ? a : b);
      final tp = TextPainter(
        text: TextSpan(
          text: cage.sum.toString(),
          style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(topLeft.col * cellSize + 3, topLeft.row * cellSize + 3),
      );
    }
  }

  static void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint,
      double dashLen, double gapLen) {
    final dir = (end - start);
    final total = dir.distance;
    if (total == 0) return;
    final unit = dir / total;
    double drawn = 0;
    bool drawing = true;
    while (drawn < total) {
      final segLen = drawing ? dashLen : gapLen;
      final next = drawn + segLen;
      if (drawing) {
        canvas.drawLine(
          start + unit * drawn,
          start + unit * next.clamp(0, total),
          paint,
        );
      }
      drawn = next;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(CagePainter oldDelegate) =>
      oldDelegate.cages != cages || oldDelegate.cellSize != cellSize;
}
