import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../domain/ball.dart';

class BallComponent extends PositionComponent {
  BallComponent({required this.ball})
      : super(
          position: ball.position.clone(),
          size: Vector2.all(Ball.radiusM * 2),
          anchor: Anchor.center,
        );

  final Ball ball;

  static const _ballColors = <int, Color>{
    1: Color(0xFFFFD600),
    2: Color(0xFF1565C0),
    3: Color(0xFFC62828),
    4: Color(0xFF6A1B9A),
    5: Color(0xFFE65100),
    6: Color(0xFF2E7D32),
    7: Color(0xFF880E4F),
    8: Color(0xFF212121),
    9: Color(0xFFFFD600),
    10: Color(0xFF1565C0),
    11: Color(0xFFC62828),
    12: Color(0xFF6A1B9A),
    13: Color(0xFFE65100),
    14: Color(0xFF2E7D32),
    15: Color(0xFF880E4F),
  };

  void syncFromBall() {
    if (!ball.isPocketed) position.setFrom(ball.position);
  }

  @override
  void render(Canvas canvas) {
    if (ball.isPocketed) return;
    final r = Ball.radiusM;
    final center = Offset(r, r);
    if (ball.isCue) {
      _drawCueBall(canvas, center, r);
    } else if (ball.type == BallType.caromYellow) {
      _drawSolidBall(canvas, center, r, const Color(0xFFFFD600));
    } else if (ball.type == BallType.caromRed) {
      _drawSolidBall(canvas, center, r, const Color(0xFFC62828));
    } else {
      _drawNumberedBall(canvas, center, r);
    }
  }

  void _drawCueBall(Canvas canvas, Offset center, double r) {
    // Shadow
    canvas.drawCircle(center + Offset(r * 0.06, r * 0.08), r * 0.92,
        Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // Base
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    // Specular highlight
    canvas.drawCircle(center - Offset(r * 0.28, r * 0.28), r * 0.22,
        Paint()..color = Colors.white.withOpacity(0.6));
    // Outline
    canvas.drawCircle(center, r,
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = r * 0.04);
  }

  void _drawSolidBall(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(center + Offset(r * 0.06, r * 0.08), r * 0.92,
        Paint()..color = Colors.black.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(center, r, Paint()..color = color);
    canvas.drawCircle(center - Offset(r * 0.28, r * 0.28), r * 0.22,
        Paint()..color = Colors.white.withOpacity(0.45));
    canvas.drawCircle(center, r,
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = r * 0.04);
  }

  void _drawNumberedBall(Canvas canvas, Offset center, double r) {
    final color = _ballColors[ball.number] ?? Colors.grey;
    final isStripe = ball.type == BallType.stripe;

    // Shadow
    canvas.drawCircle(center + Offset(r * 0.06, r * 0.08), r * 0.92,
        Paint()..color = Colors.black.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    if (isStripe) {
      // White base
      canvas.drawCircle(center, r, Paint()..color = Colors.white);
      // Colour stripe band (clip to circle)
      final path = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTWH(0, r * 0.3, r * 2, r * 1.4),
        Paint()..color = color,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, r, Paint()..color = color);
    }

    // White number circle
    canvas.drawCircle(center, r * 0.42, Paint()..color = Colors.white);

    // Number
    final tp = TextPainter(
      text: TextSpan(
        text: ball.number.toString(),
        style: TextStyle(
          color: Colors.black87,
          fontSize: r * 0.82,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    // Specular highlight
    canvas.drawCircle(center - Offset(r * 0.28, r * 0.28), r * 0.18,
        Paint()..color = Colors.white.withOpacity(0.45));

    // Outline
    canvas.drawCircle(center, r,
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = r * 0.04);
  }
}
