import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../domain/ball.dart';
import '../../domain/game_state.dart';

/// Draws a glowing ring around balls the current player must target.
class TargetHighlightComponent extends Component {
  TargetHighlightComponent({required this.balls}) : super(priority: 10);

  final List<Ball> balls;
  PlayerGroup group = PlayerGroup.none;

  @override
  void render(Canvas canvas) {
    if (group == PlayerGroup.none) return;
    final targetType =
        group == PlayerGroup.solid ? BallType.solid : BallType.stripe;
    const r = Ball.radiusM;

    final outerPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.006;
    final glowPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.006);

    for (final ball in balls) {
      if (ball.isPocketed) continue;
      if (ball.type != targetType) continue;
      final c = Offset(ball.position.x, ball.position.y);
      canvas.drawCircle(c, r + 0.009, glowPaint);
      canvas.drawCircle(c, r + 0.005, outerPaint);
    }
  }
}
