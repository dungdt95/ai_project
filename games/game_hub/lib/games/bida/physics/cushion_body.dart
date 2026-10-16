import 'package:flame_forge2d/flame_forge2d.dart';
import '../domain/table.dart';

/// Static edge bodies forming the 4 cushions of the table.
class CushionBody {
  static void createAll(Forge2DWorld world) {
    const w = BidaTable.widthM;
    const h = BidaTable.heightM;
    final edges = [
      [Vector2(0, 0), Vector2(w, 0)],    // top
      [Vector2(w, 0), Vector2(w, h)],    // right
      [Vector2(w, h), Vector2(0, h)],    // bottom
      [Vector2(0, h), Vector2(0, 0)],    // left
    ];

    for (final edge in edges) {
      final def = BodyDef()..type = BodyType.static;
      final body = world.createBody(def);
      final shape = EdgeShape()..set(edge[0], edge[1]);
      final fd = FixtureDef(shape)
        ..restitution = 0.7
        ..friction = 0.1
        ..userData = 'cushion';
      body.createFixture(fd);
    }
  }
}
