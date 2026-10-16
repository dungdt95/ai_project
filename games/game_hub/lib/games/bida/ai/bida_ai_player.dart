import 'dart:math';
import 'package:flame/components.dart';
import '../domain/ball.dart';
import '../domain/game_state.dart';
import '../domain/shot.dart';
import '../domain/table.dart';
import '../domain/variant.dart';

/// Stateless AI shot computation. All methods are static — safe to call from compute().
class BidaAiPlayer {
  static final _rng = Random();

  static Shot computeShot(BidaGameState state, AiLevel level) {
    if (state.variant == BidaVariant.carom) {
      return _caromShot(state, level);
    }
    switch (level) {
      case AiLevel.easy:
        return _easyShot(state);
      case AiLevel.medium:
        return _mediumShot(state);
      case AiLevel.hard:
        return _hardShot(state);
    }
  }

  // ── Carom: aim at nearest object ball with randomness by level ────────────

  static Shot _caromShot(BidaGameState state, AiLevel level) {
    final objects = state.activeBalls.where((b) => !b.isCue).toList();
    if (objects.isEmpty) return _safetyShot();
    final cue = state.cueBall;

    // Pick nearest object ball
    objects.sort((a, b) => _dist(cue.position, a.position).compareTo(_dist(cue.position, b.position)));
    final target = objects.first;

    final base = atan2(
      target.position.y - cue.position.y,
      target.position.x - cue.position.x,
    );
    final errorRad = switch (level) {
      AiLevel.easy   => 0.45,
      AiLevel.medium => 0.18,
      AiLevel.hard   => 0.06,
    };
    final angle = base + (_rng.nextDouble() - 0.5) * errorRad;
    final power = switch (level) {
      AiLevel.easy   => 0.45 + _rng.nextDouble() * 0.25,
      AiLevel.medium => 0.60 + _rng.nextDouble() * 0.20,
      AiLevel.hard   => 0.70 + _rng.nextDouble() * 0.15,
    };
    return Shot(direction: Vector2(cos(angle), sin(angle)), power: power);
  }

  // ── Easy: random target, large aim error ──────────────────────────────────

  static Shot _easyShot(BidaGameState state) {
    final targets = _getTargetBalls(state);
    if (targets.isEmpty) return _safetyShot();

    final cue = state.cueBall;
    final target = targets[_rng.nextInt(targets.length)];
    final base = atan2(
      target.position.y - cue.position.y,
      target.position.x - cue.position.x,
    );
    final angle = base + (_rng.nextDouble() - 0.5) * 0.70; // ±20°
    return Shot(
      direction: Vector2(cos(angle), sin(angle)),
      power: 0.35 + _rng.nextDouble() * 0.35,
    );
  }

  // ── Medium: best direct pocket shot, ±5° error ───────────────────────────

  static Shot _mediumShot(BidaGameState state) =>
      _findBestPocketShot(state, errorRad: 0.087) ?? _easyShot(state);

  // ── Hard: best pocket shot, ±2° error ────────────────────────────────────

  static Shot _hardShot(BidaGameState state) =>
      _findBestPocketShot(state, errorRad: 0.035) ?? _mediumShot(state);

  // ── Core ghost-ball search ────────────────────────────────────────────────

  static Shot? _findBestPocketShot(BidaGameState state, {required double errorRad}) {
    final cue = state.cueBall;
    final targets = _getTargetBalls(state);
    final active = state.activeBalls;

    _ShotCandidate? best;

    for (final target in targets) {
      for (final pocket in BidaTable.pocketPositions) {
        final c = _evalPocketShot(cue, target, pocket, active, errorRad: errorRad);
        if (c != null && (best == null || c.score > best.score)) best = c;
      }
    }
    return best?.shot;
  }

  static _ShotCandidate? _evalPocketShot(
    Ball cue, Ball target, Vector2 pocket,
    List<Ball> active, {required double errorRad}
  ) {
    // Ghost-ball position: where cue center must be to send target to pocket
    final ghost = _ghostBallPos(target.position, pocket);
    if (ghost == null) return null;

    // Ghost ball must be inside table
    const r = Ball.radiusM;
    if (ghost.x < r || ghost.x > BidaTable.widthM - r) return null;
    if (ghost.y < r || ghost.y > BidaTable.heightM - r) return null;

    // Cut angle quality (dot of cue→target dir and target→pocket dir)
    final cueToBallDir = _dir(cue.position, target.position);
    final toPocketDir = _dir(target.position, pocket);
    final cutDot = cueToBallDir.dot(toPocketDir);
    if (cutDot < 0.08) return null; // cut angle > ~85° — unreliable

    // Both paths must be clear
    if (!_isPathClear(cue.position, ghost, active, ex1: 0, ex2: target.id)) return null;
    if (!_isPathClear(target.position, pocket, active, ex1: 0, ex2: target.id)) return null;

    // Score: prefer short total distance and straight cut angles
    final d1 = _dist(cue.position, target.position);
    final d2 = _dist(target.position, pocket);
    final score = (1.0 / (1.0 + d1 + d2 * 0.5)) * cutDot *
        (0.85 + _rng.nextDouble() * 0.3); // slight noise for variety

    // Aim toward ghost ball with small error
    final baseAngle = atan2(ghost.y - cue.position.y, ghost.x - cue.position.x);
    final angle = baseAngle + (_rng.nextDouble() - 0.5) * errorRad * 2;

    // Power scales with distance and cut angle
    final power = (0.28 + d1 / BidaTable.widthM * 0.45 + cutDot * 0.12).clamp(0.25, 0.82);

    return _ShotCandidate(
      shot: Shot(direction: Vector2(cos(angle), sin(angle)), power: power),
      score: score,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<Ball> _getTargetBalls(BidaGameState state) {
    final active = state.activeBalls.where((b) => !b.isCue).toList();

    // Rotation variants (9-ball / VN): must target lowest-numbered ball
    final isRotation = state.variant == BidaVariant.nineBall ||
        state.variant == BidaVariant.vnBall ||
        state.variant == BidaVariant.carom;
    if (isRotation) {
      if (active.isEmpty) return [];
      final lowestId = active.map((b) => b.id).reduce(min);
      return active.where((b) => b.id == lowestId).toList();
    }

    // 8-ball: own group
    if (!state.isGroupAssigned) {
      return active.where((b) => b.type == BallType.solid || b.type == BallType.stripe).toList();
    }
    final myGroup = state.playerGroups[state.currentPlayer];
    if (myGroup == PlayerGroup.none) return [];
    final targetType = myGroup == PlayerGroup.solid ? BallType.solid : BallType.stripe;
    final own = active.where((b) => b.type == targetType).toList();
    return own.isEmpty ? active.where((b) => b.type == BallType.eight).toList() : own;
  }

  static Shot _safetyShot() {
    final angle = _rng.nextDouble() * 2 * pi;
    return Shot(
      direction: Vector2(cos(angle), sin(angle)),
      power: 0.20 + _rng.nextDouble() * 0.15,
    );
  }

  /// Ghost-ball position: cue center required to pot `targetPos` toward `pocket`.
  static Vector2? _ghostBallPos(Vector2 targetPos, Vector2 pocket) {
    final dx = pocket.x - targetPos.x;
    final dy = pocket.y - targetPos.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return null;
    return Vector2(
      targetPos.x - dx / len * Ball.radiusM * 2,
      targetPos.y - dy / len * Ball.radiusM * 2,
    );
  }

  /// True if no active ball (other than excluded ones) blocks the line from→to.
  static bool _isPathClear(Vector2 from, Vector2 to, List<Ball> balls, {int? ex1, int? ex2}) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return true;
    final nx = dx / len;
    final ny = dy / len;
    const threshold = Ball.radiusM * 2 + 0.003;

    for (final b in balls) {
      if (b.id == ex1 || b.id == ex2) continue;
      final bx = b.position.x - from.x;
      final by = b.position.y - from.y;
      final t = (bx * nx + by * ny).clamp(0.0, len);
      final px = from.x + nx * t - b.position.x;
      final py = from.y + ny * t - b.position.y;
      if (px * px + py * py < threshold * threshold) return false;
    }
    return true;
  }

  static Vector2 _dir(Vector2 from, Vector2 to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = sqrt(dx * dx + dy * dy);
    return len > 0.001 ? Vector2(dx / len, dy / len) : Vector2(1, 0);
  }

  static double _dist(Vector2 a, Vector2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return sqrt(dx * dx + dy * dy);
  }
}

class _ShotCandidate {
  const _ShotCandidate({required this.shot, required this.score});
  final Shot shot;
  final double score;
}
