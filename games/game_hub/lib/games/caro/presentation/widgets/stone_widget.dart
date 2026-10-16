import 'package:flutter/material.dart';
import '../../domain/move.dart';

/// Draws a single Caro stone (X or O).
class StoneWidget extends StatelessWidget {
  const StoneWidget({super.key, required this.player, this.size = 28});

  final Player player;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StonePainter(player, size)),
    );
  }
}

class _StonePainter extends CustomPainter {
  const _StonePainter(this.player, this.size);
  final Player player;
  final double size;

  @override
  void paint(Canvas canvas, Size sz) {
    final center = Offset(sz.width / 2, sz.height / 2);
    final radius = size / 2 - 2;
    final paint = Paint()..style = PaintingStyle.fill;

    if (player == Player.o) {
      // Blue circle for O.
      paint.color = const Color(0xFF1565C0);
      canvas.drawCircle(center, radius, paint);
      paint
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius - 2, paint);
    } else {
      // Red X for X.
      final strokePaint = Paint()
        ..color = const Color(0xFFC62828)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      final pad = size * 0.22;
      canvas.drawLine(Offset(pad, pad), Offset(sz.width - pad, sz.height - pad), strokePaint);
      canvas.drawLine(Offset(sz.width - pad, pad), Offset(pad, sz.height - pad), strokePaint);
    }
  }

  @override
  bool shouldRepaint(_StonePainter old) => old.player != player;
}
