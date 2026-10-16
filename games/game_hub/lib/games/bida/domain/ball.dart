import 'package:flame/components.dart';

enum BallType { cue, solid, stripe, eight, numbered, caromWhite, caromYellow, caromRed }

class Ball {
  Ball({
    required this.id,
    required this.type,
    required this.number,
    required this.position,
    this.isPocketed = false,
  }) : velocity = Vector2.zero(),
       spin = Vector2.zero();

  final int id;
  final BallType type;
  final int number;
  Vector2 position;
  Vector2 velocity;
  Vector2 spin;
  bool isPocketed;

  bool get isCue => type == BallType.cue;

  static const double radiusM = 0.02858; // 57.15mm / 2 in meters
}
