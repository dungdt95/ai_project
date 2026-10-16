import 'package:flame_forge2d/flame_forge2d.dart';
import '../domain/ball.dart';
import '../domain/shot.dart';
import '../domain/shot_result.dart';
import '../domain/table.dart';
import 'ball_body.dart';
import 'cushion_body.dart';
import 'pocket.dart';

class BidaPhysicsWorld {
  BidaPhysicsWorld(this._world);

  final Forge2DWorld _world;

  final Map<int, BallBody> _ballBodies = {};
  final List<PocketSensor> _pockets = [];
  // Bodies queued for removal — destroyBody must NOT be called inside a step/contact callback.
  final Set<int> _pendingRemoval = {};

  // Per-shot tracking
  final List<int> _pocketedThisShot = [];
  int? _firstBallHit;
  int? _secondBallHit;
  double? _secondBallHitTime;
  final List<CushionHit> _cushionHitsThisShot = [];
  bool _cueScratch = false;
  final List<int> _leftTable = [];
  double _shotTime = 0;

  static const double _sleepThreshold = 0.01;
  static const double _sleepDuration = 0.3;
  final Map<int, double> _belowThresholdFor = {};

  void init(List<Ball> balls, {bool hasPockets = true}) {
    CushionBody.createAll(_world);

    if (hasPockets) {
      for (final pos in BidaTable.pocketPositions) {
        final sensor = PocketSensor(
          world: _world,
          position: pos,
          onBallEntered: onBallPocketed,
        );
        _pockets.add(sensor);
      }
    }

    for (final ball in balls) {
      if (!ball.isPocketed) {
        final body = BallBody(
          world: _world,
          ball: ball,
          onBallContact: onBallContact,
          onCushionContact: onCushionContact,
        );
        _ballBodies[ball.id] = body;
      }
    }
  }

  void applyShot(Shot shot) {
    _resetShotTracking();
    final cueBody = _ballBodies[0];
    if (cueBody == null) return;
    final impulse = shot.direction.normalized() * shot.impulse;
    cueBody.body.applyLinearImpulse(impulse);
    cueBody.ball.spin = shot.spin.clone();
  }

  /// Call BEFORE super.update(dt) so impulses are applied in the upcoming step.
  void preStep(double dt) {
    _shotTime += dt;
    _applySpinForces(dt);
  }

  /// Call AFTER super.update(dt) to track sleep and process removals.
  void postStep(double dt) {
    processPendingRemovals();
    for (final entry in _ballBodies.entries) {
      final v = entry.value.body.linearVelocity.length;
      if (v < _sleepThreshold) {
        _belowThresholdFor[entry.key] = (_belowThresholdFor[entry.key] ?? 0) + dt;
      } else {
        _belowThresholdFor[entry.key] = 0;
      }
    }
  }

  bool get allAtRest {
    if (_ballBodies.isEmpty) return true;
    return _ballBodies.keys.every(
      (id) => (_belowThresholdFor[id] ?? 0) >= _sleepDuration,
    );
  }

  ShotResult collectResult() {
    final secondMs = _secondBallHitTime != null ? _secondBallHitTime! * 1000 : double.infinity;
    final cueCushionsBefore = _cushionHitsThisShot
        .where((h) => h.ballId == 0 && h.timeMs < secondMs)
        .length;
    return ShotResult(
      pocketedIds: List.unmodifiable(_pocketedThisShot),
      firstBallHitId: _firstBallHit,
      secondBallHitId: _secondBallHit,
      cueCushionCountBeforeSecondBall: cueCushionsBefore,
      cushionHits: List.unmodifiable(_cushionHitsThisShot),
      cueBallScratched: _cueScratch,
      ballsLeftTableIds: List.unmodifiable(_leftTable),
    );
  }

  void syncBalls(List<Ball> balls) {
    for (final ball in balls) {
      final body = _ballBodies[ball.id];
      if (body != null && !ball.isPocketed) {
        ball.position.setFrom(body.body.position);
        ball.velocity.setFrom(body.body.linearVelocity);
      }
    }
  }

  void removeBall(int id) {
    final body = _ballBodies.remove(id);
    if (body != null) _world.destroyBody(body.body);
  }

  void restoreBall(Ball ball) {
    if (_ballBodies.containsKey(ball.id)) return;
    final body = BallBody(
      world: _world,
      ball: ball,
      onBallContact: onBallContact,
      onCushionContact: onCushionContact,
    );
    _ballBodies[ball.id] = body;
    _belowThresholdFor[ball.id] = _sleepDuration; // treat as already at rest
  }

  /// Must be called AFTER the physics step (not inside contact callbacks).
  void processPendingRemovals() {
    if (_pendingRemoval.isEmpty) return;
    for (final id in _pendingRemoval) {
      removeBall(id);
    }
    _pendingRemoval.clear();
  }

  // Public so BidaContactListener can reference them as tear-offs
  void onBallPocketed(int ballId) {
    if (ballId == 0) _cueScratch = true;
    if (!_pocketedThisShot.contains(ballId)) {
      _pocketedThisShot.add(ballId);
    }
    // Don't destroy body here — world is locked during contact callbacks.
    _pendingRemoval.add(ballId);
  }

  void onBallContact(int ballAId, int ballBId) {
    final isCueA = ballAId == 0;
    final isCueB = ballBId == 0;
    if (!isCueA && !isCueB) return;
    final objId = isCueA ? ballBId : ballAId;
    if (_firstBallHit == null) {
      _firstBallHit = objId;
    } else if (_secondBallHit == null && objId != _firstBallHit) {
      _secondBallHit = objId;
      _secondBallHitTime = _shotTime;
    }
  }

  void onCushionContact(int ballId) {
    _cushionHitsThisShot.add(CushionHit(ballId: ballId, timeMs: _shotTime * 1000));
  }

  void _resetShotTracking() {
    _pocketedThisShot.clear();
    _firstBallHit = null;
    _secondBallHit = null;
    _secondBallHitTime = null;
    _cushionHitsThisShot.clear();
    _cueScratch = false;
    _leftTable.clear();
    _shotTime = 0;
    _belowThresholdFor.clear();
  }

  void _applySpinForces(double dt) {
    final cueBody = _ballBodies[0];
    if (cueBody == null) return;
    final spin = cueBody.ball.spin;
    if (spin.length < 0.01) return;
    final decay = (1.0 - dt * 2.0).clamp(0.0, 1.0);
    spin.scale(decay);
    cueBody.body.applyLinearImpulse(Vector2(-spin.x * 0.01, 0));
  }
}
