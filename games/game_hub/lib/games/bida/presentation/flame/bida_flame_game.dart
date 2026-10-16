import 'dart:ui' show lerpDouble, Offset, Size;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import '../../domain/ball.dart';
import '../../domain/game_state.dart' show BidaGameState, PlayerGroup;
import '../../domain/shot.dart';
import '../../domain/shot_result.dart';
import '../../domain/table.dart';
import '../../physics/physics_world.dart';
import '../../physics/pocket.dart';
import 'table_component.dart';
import 'ball_component.dart';
import 'aim_component.dart';
import 'highlight_component.dart';

/// Pixels per meter — world-to-screen scale.
const double kPPM = 200.0;

/// Table occupies this fraction of the screen (0.8 = 80%).
const double kTableScale = 0.8;

class BidaFlameGame extends Forge2DGame {
  BidaFlameGame({required this.state, required this.onShotResult})
      : super(gravity: Vector2.zero(), zoom: kPPM);

  BidaGameState state;
  final void Function(BidaGameState, ShotResult) onShotResult;

  late BidaPhysicsWorld physicsWorld;
  final Map<int, BallComponent> ballComponents = {};
  late AimComponent aimComponent;
  late TargetHighlightComponent _highlightComponent;

  PlayerGroup highlightGroup = PlayerGroup.none;

  bool _shotRunning = false;

  // Camera lerp target (in world meters)
  Vector2 _camTarget = Vector2(BidaTable.widthM / 2, BidaTable.heightM / 2);
  static const double _camLerpSpeed = 6.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Table at 80% of screen — show more world space around it
    camera.viewfinder
      ..visibleGameSize = Vector2(
          BidaTable.widthM / kTableScale, BidaTable.heightM / kTableScale)
      ..anchor = Anchor.center
      ..position = Vector2(BidaTable.widthM / 2, BidaTable.heightM / 2);

    // Physics
    physicsWorld = BidaPhysicsWorld(world);
    final listener = BidaContactListener(
      onBallPocketed: physicsWorld.onBallPocketed,
      onBallBallContact: physicsWorld.onBallContact,
      onBallCushionContact: physicsWorld.onCushionContact,
    );
    world.physicsWorld.setContactListener(listener);
    physicsWorld.init(state.balls, hasPockets: state.variant.hasPockets);

    // Components
    world.add(TableComponent(hasPockets: state.variant.hasPockets));
    for (final ball in state.balls) {
      final comp = BallComponent(ball: ball);
      ballComponents[ball.id] = comp;
      world.add(comp);
    }

    aimComponent = AimComponent(balls: state.balls);
    world.add(aimComponent);

    _highlightComponent = TargetHighlightComponent(balls: state.balls);
    world.add(_highlightComponent);
  }

  @override
  void update(double dt) {
    _highlightComponent.group = highlightGroup;

    if (_shotRunning) {
      physicsWorld.preStep(dt);
    }

    super.update(dt);

    if (_shotRunning) {
      physicsWorld.postStep(dt);
      physicsWorld.syncBalls(state.balls);

      for (final ball in state.balls) {
        ballComponents[ball.id]?.syncFromBall();
      }

      // Camera: follow cue ball while shot runs
      final cueBall = _cueBall;
      if (cueBall != null && !cueBall.isPocketed) {
        _camTarget = cueBall.position.clone();
      }

      if (physicsWorld.allAtRest) {
        _shotRunning = false;
        final result = physicsWorld.collectResult();

        for (final id in result.pocketedIds) {
          if (id == 0) continue; // Cue ball: keep component alive — isPocketed hides it
          final comp = ballComponents.remove(id);
          if (comp != null) world.remove(comp);
        }

        // Camera: drift back to table centre
        _camTarget = Vector2(BidaTable.widthM / 2, BidaTable.heightM / 2);

        aimComponent.visible = true;
        onShotResult(state, result);
      }
    }

    // Smooth camera lerp every frame
    final cur = camera.viewfinder.position;
    camera.viewfinder.position = Vector2(
      lerpDouble(cur.x, _camTarget.x, (_camLerpSpeed * dt).clamp(0, 1))!,
      lerpDouble(cur.y, _camTarget.y, (_camLerpSpeed * dt).clamp(0, 1))!,
    );
  }

  void applyShot(Shot shot) {
    if (_shotRunning) return;
    aimComponent.visible = false;
    physicsWorld.applyShot(shot);
    _shotRunning = true;
  }

  /// Restores the cue ball in physics and moves its existing component to the new position.
  void restoreCueBall(Ball cueBall) {
    physicsWorld.restoreBall(cueBall);
    final comp = ballComponents[cueBall.id];
    if (comp != null) {
      // Reposition the existing component — avoids async world.remove/add glitch.
      comp.position.setFrom(cueBall.position);
    } else {
      final newComp = BallComponent(ball: cueBall);
      ballComponents[cueBall.id] = newComp;
      world.add(newComp);
    }
    aimComponent.balls = state.balls;
  }

  Ball? get _cueBall {
    try { return state.balls.firstWhere((b) => b.isCue); } catch (_) { return null; }
  }

  /// Convert a Flutter local offset (pixels, top-left origin) inside the
  /// GameWidget to world coordinates (meters).
  Vector2 widgetPosToWorld(Offset screenPos, Size widgetSize) {
    const visW = BidaTable.widthM / kTableScale;
    const visH = BidaTable.heightM / kTableScale;
    // Top-left visible world coord (camera center - half visible size)
    const leftWorld = BidaTable.widthM / 2 - visW / 2;
    const topWorld  = BidaTable.heightM / 2 - visH / 2;
    return Vector2(
      leftWorld + screenPos.dx / widgetSize.width  * visW,
      topWorld  + screenPos.dy / widgetSize.height * visH,
    );
  }
}
