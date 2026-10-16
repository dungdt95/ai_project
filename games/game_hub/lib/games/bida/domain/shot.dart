import 'package:flame/components.dart';

class Shot {
  Shot({
    required this.direction,
    required this.power,
    Vector2? spin,
  }) : spin = spin ?? Vector2.zero();

  /// Normalised direction vector.
  final Vector2 direction;

  /// 0.0 – 1.0.
  final double power;

  /// Spin offset from cue ball centre (-1..1 each axis). x=side, y=top/back.
  final Vector2 spin;

  /// Max impulse in N·s applied to cue ball.
  static const double maxImpulse = 0.9;

  double get impulse => power * maxImpulse;
}
