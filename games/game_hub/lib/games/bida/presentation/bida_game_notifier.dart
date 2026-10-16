import 'dart:math';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bida_stats_service.dart';
import '../domain/ball.dart';
import '../domain/game_state.dart';
import '../domain/shot.dart';
import '../domain/shot_result.dart';
import '../domain/table.dart';
import '../domain/variant.dart';
import '../domain/rules/eight_ball_rules.dart';
import '../domain/rules/nine_ball_rules.dart';
import '../domain/rules/vn_ball_rules.dart';
import '../domain/rules/carom_rules.dart';
import '../domain/rules/rules.dart';

final bidaGameProvider =
    StateNotifierProvider<BidaGameNotifier, BidaGameState>((ref) {
  return BidaGameNotifier();
});

class BidaGameNotifier extends StateNotifier<BidaGameState> {
  BidaGameNotifier()
      : super(_buildInitial(BidaVariant.eightBall, BidaMode.vsHuman));

  static BidaGameState _buildInitial(BidaVariant v, BidaMode m, {AiLevel? ai}) {
    final rules = _rulesFor(v);
    final balls = m == BidaMode.daily ? _dailyRack() : rules.rackBalls();
    return BidaGameState(
      variant: v,
      mode: m,
      aiLevel: ai,
      balls: balls,
      currentPlayer: 0,
    );
  }

  static BidaRules _rulesFor(BidaVariant v) {
    switch (v) {
      case BidaVariant.eightBall: return EightBallRules();
      case BidaVariant.nineBall:  return NineBallRules();
      case BidaVariant.vnBall:    return VnBallRules();
      case BidaVariant.carom:     return CaromRules();
    }
  }

  /// Seeded rack for daily challenge — shuffled 8-ball layout based on date.
  static List<Ball> _dailyRack() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(seed);

    // Base positions from standard 8-ball triangle
    final fp = BidaTable.footSpot;
    final r = Ball.radiusM * 2 + 0.002;
    final positions = <Vector2>[];
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col <= row; col++) {
        positions.add(Vector2(
          fp.x + row * r * 0.866,
          fp.y - row * r / 2 + col * r,
        ));
      }
    }

    // Shuffle numbered balls 1–15, keep 8 in slot 4 (middle), keep 1 at apex
    final nums = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15];
    nums.shuffle(rng);
    // Insert 8 at index 4 (centre of triangle) and 1 at apex (index 0)
    nums.remove(1);
    final finalNums = [1, ...nums.sublist(0, 4), 8, ...nums.sublist(4)];

    final balls = <Ball>[
      Ball(id: 0, type: BallType.cue, number: 0,
           position: BidaTable.headSpot.clone()),
    ];
    for (int i = 0; i < finalNums.length; i++) {
      final n = finalNums[i];
      balls.add(Ball(
        id: n, number: n,
        type: n == 8 ? BallType.eight : (n <= 7 ? BallType.solid : BallType.stripe),
        position: positions[i].clone(),
      ));
    }
    return balls;
  }

  void startGame({
    required BidaVariant variant,
    required BidaMode mode,
    AiLevel? aiLevel,
  }) {
    state = _buildInitial(variant, mode, ai: aiLevel);
  }

  double _aimAngle = 0;
  double _power = 0.5;
  Offset _spin = Offset.zero;

  double get aimAngle => _aimAngle;
  double get power => _power;
  Offset get spin => _spin;

  void setAimAngle(double angle) => _aimAngle = angle;
  void setPower(double p) {
    _power = p.clamp(0.0, 1.0);
    state = state.copyWith();
  }
  void setSpin(Offset s) => _spin = s;

  void confirmShot() {
    if (state.phase != TurnPhase.aiming) return;
    state = state.copyWith(phase: TurnPhase.running);
  }

  /// Called by FlameGame after physics settle.
  Future<void> onShotSettled(BidaGameState updated, ShotResult result) async {
    // ── Practice mode: no rules, same player, no winner ──────────────────────
    if (state.mode == BidaMode.practice) {
      for (final b in updated.balls) {
        if (result.pocketedIds.contains(b.id) && b.id != 0) b.isPocketed = true;
      }
      final msg = result.pocketedIds.isEmpty ? null : '${result.pocketedIds.length} bi vào lỗ!';
      state = updated.copyWith(
        shotCount: state.shotCount + 1,
        phase: TurnPhase.aiming,
        message: msg,
        clearMessage: msg == null,
      );
      return;
    }

    // ── Normal rules evaluation ───────────────────────────────────────────────
    final rules = _rulesFor(state.variant);
    final evaluated = rules.evaluate(updated, result);

    // Preserve placing/over phases; default others to aiming
    if (evaluated.phase == TurnPhase.over || evaluated.phase == TurnPhase.placing) {
      state = evaluated;
    } else {
      state = evaluated.copyWith(phase: TurnPhase.aiming);
    }

    // ── Post-game persistence ─────────────────────────────────────────────────
    if (evaluated.phase == TurnPhase.over) {
      await _saveStats(evaluated, result);
    }
  }

  /// Called when the player taps to confirm cue ball position (ball-in-hand).
  void confirmCueBallPlacement(Vector2 pos) {
    final cue = state.cueBall;
    cue.position = pos.clone();
    cue.isPocketed = false;
    cue.velocity = Vector2.zero();
    cue.spin = Vector2.zero();
    state = state.copyWith(phase: TurnPhase.aiming, clearMessage: true);
  }

  Future<void> _saveStats(BidaGameState finalState, ShotResult result) async {
    final svc = BidaStatsService.instance;
    final playerWon = finalState.winner == 0;

    // Save game record (only real vs-human/AI games)
    if (state.mode != BidaMode.practice) {
      final record = BidaGameRecord(
        variant: state.variant,
        mode: state.mode,
        playerWon: playerWon,
        shots: finalState.shotCount,
        fouls: finalState.fouls,
        playedAt: DateTime.now(),
        vsAiLevel: state.aiLevel,
      );
      await svc.saveGame(record);

      // Save daily challenge result
      if (state.mode == BidaMode.daily) {
        await svc.saveDailyResult(finalState.shotCount, finalState.fouls);
      }

      // Check & unlock achievements (fire and forget)
      svc.checkAndUnlockAchievements();
    }
  }

  Shot buildShot() {
    return Shot(
      direction: Vector2(cos(_aimAngle), sin(_aimAngle)),
      power: _power,
      spin: Vector2(_spin.dx.toDouble(), _spin.dy.toDouble()),
    );
  }

  void newGame() {
    state = _buildInitial(state.variant, state.mode, ai: state.aiLevel);
  }
}
