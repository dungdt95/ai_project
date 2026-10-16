import 'package:flame_forge2d/flame_forge2d.dart';
import '../domain/table.dart';
import 'ball_body.dart';

class PocketSensor {
  PocketSensor({
    required Forge2DWorld world,
    required Vector2 position,
    required this.onBallEntered,
  }) {
    final def = BodyDef()
      ..type = BodyType.static
      ..position = position;
    _body = world.createBody(def);

    final shape = CircleShape()..radius = BidaTable.pocketRadiusM;
    final fd = FixtureDef(shape)
      ..isSensor = true
      ..userData = this;
    _body.createFixture(fd);
  }

  final void Function(int ballId) onBallEntered;
  late final Body _body;
}

/// Contact listener that handles ball–pocket and ball–cushion contacts.
class BidaContactListener extends ContactListener {
  BidaContactListener({
    required this.onBallPocketed,
    required this.onBallBallContact,
    required this.onBallCushionContact,
  });

  final void Function(int ballId) onBallPocketed;
  final void Function(int a, int b) onBallBallContact;
  final void Function(int ballId) onBallCushionContact;

  @override
  void beginContact(Contact contact) {
    final a = contact.fixtureA.userData;
    final b = contact.fixtureB.userData;

    if (a is PocketSensor && b is BallBody) {
      onBallPocketed(b.ball.id);
    } else if (b is PocketSensor && a is BallBody) {
      onBallPocketed(a.ball.id);
    } else if (a is BallBody && b is BallBody) {
      onBallBallContact(a.ball.id, b.ball.id);
    } else if (a is BallBody && b == 'cushion') {
      onBallCushionContact(a.ball.id);
    } else if (b is BallBody && a == 'cushion') {
      onBallCushionContact(b.ball.id);
    }
  }
}
