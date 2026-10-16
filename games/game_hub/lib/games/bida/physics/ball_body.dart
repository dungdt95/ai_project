import 'package:flame_forge2d/flame_forge2d.dart';
import '../domain/ball.dart';

class BallBody {
  BallBody({
    required Forge2DWorld world,
    required this.ball,
    required this.onBallContact,
    required this.onCushionContact,
  }) {
    final def = BodyDef()
      ..type = BodyType.dynamic
      ..position = ball.position.clone()
      ..linearDamping = 2.2
      ..angularDamping = 1.5
      ..bullet = true;

    body = world.createBody(def);

    final shape = CircleShape()..radius = Ball.radiusM;
    final fd = FixtureDef(shape)
      ..density = 1.7
      ..friction = 0.2
      ..restitution = 0.88
      ..userData = this;

    body.createFixture(fd);
  }

  final Ball ball;
  final void Function(int a, int b) onBallContact;
  final void Function(int ballId) onCushionContact;
  late final Body body;
}
