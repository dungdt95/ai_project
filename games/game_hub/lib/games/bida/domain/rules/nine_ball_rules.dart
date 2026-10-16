import 'dart:math';
import 'package:flame/components.dart';
import '../ball.dart';
import '../game_state.dart';
import '../shot_result.dart';
import '../table.dart';
import 'rules.dart';

class NineBallRules extends BidaRules {
  @override
  List<Ball> rackBalls() {
    final balls = <Ball>[];

    balls.add(Ball(
      id: 0, type: BallType.cue, number: 0,
      position: BidaTable.headSpot.clone(),
    ));

    // Diamond rack: 1 at apex (foot spot), 9 in centre, 2-8 random
    final others = [2, 3, 4, 5, 6, 7, 8]..shuffle();
    final rackOrder = [1, others[0], others[1], others[2], 9, others[3], others[4], others[5], others[6]];

    const d = Ball.radiusM * 2 + 0.002;
    const h = d * 0.866; // row stride (equilateral packing)
    final fp = BidaTable.footSpot;

    final positions = [
      fp.clone(),                                         // 0 → apex (1)
      Vector2(fp.x + h, fp.y - d * 0.5),                // 1
      Vector2(fp.x + h, fp.y + d * 0.5),                // 2
      Vector2(fp.x + h * 2, fp.y - d),                  // 3
      Vector2(fp.x + h * 2, fp.y),                      // 4 → centre (9)
      Vector2(fp.x + h * 2, fp.y + d),                  // 5
      Vector2(fp.x + h * 3, fp.y - d * 0.5),            // 6
      Vector2(fp.x + h * 3, fp.y + d * 0.5),            // 7
      Vector2(fp.x + h * 4, fp.y),                      // 8 → back apex
    ];

    for (int i = 0; i < rackOrder.length; i++) {
      final n = rackOrder[i];
      balls.add(Ball(
        id: n, number: n,
        type: n == 9 ? BallType.stripe : BallType.solid,
        position: positions[i],
      ));
    }
    return balls;
  }

  @override
  BidaGameState evaluate(BidaGameState state, ShotResult result) {
    final pocketed = result.pocketedIds;
    var newState = state.copyWith(shotCount: state.shotCount + 1);

    // Mark non-cue pocketed balls
    for (final b in newState.balls) {
      if (pocketed.contains(b.id) && b.id != 0) b.isPocketed = true;
    }

    final isFoul = _checkFoul(state, result);

    if (isFoul) {
      return newState.copyWith(
        currentPlayer: 1 - state.currentPlayer,
        fouls: state.fouls + 1,
        phase: result.cueBallScratched ? TurnPhase.placing : null,
        message: result.cueBallScratched
            ? 'Phạm quy! Đặt bi cái vào vị trí mong muốn.'
            : 'Phạm quy! Đổi lượt.',
      );
    }

    // Pocket the 9-ball legally → win
    if (pocketed.contains(9)) {
      return newState.copyWith(winner: state.currentPlayer, phase: TurnPhase.over);
    }

    // Update score (count of balls pocketed)
    final scored = pocketed.where((id) => id != 0).length;
    if (scored > 0) {
      final scores = List.of(newState.scores);
      scores[state.currentPlayer] += scored;
      newState = newState.copyWith(scores: scores);
    }

    if (scored > 0) {
      final lowest = _lowestActiveId(newState);
      return newState.copyWith(
        message: lowest > 0 ? 'Tiếp! Đánh bi $lowest' : null,
        clearMessage: lowest <= 0,
      );
    }

    return newState.copyWith(
      currentPlayer: 1 - state.currentPlayer,
      clearMessage: true,
    );
  }

  @override
  bool isGameOver(BidaGameState state) => state.winner != null;

  bool _checkFoul(BidaGameState state, ShotResult result) {
    if (result.cueBallScratched) return true;
    if (result.noBallHit) return true;
    if (result.ballsLeftTableIds.isNotEmpty) return true;
    // Must contact the lowest-numbered active ball first
    if (result.firstBallHitId != null) {
      if (result.firstBallHitId != _lowestActiveId(state)) return true;
    }
    return false;
  }

  int _lowestActiveId(BidaGameState state) {
    final active = state.activeBalls.where((b) => !b.isCue).toList();
    if (active.isEmpty) return -1;
    return active.map((b) => b.id).reduce(min);
  }
}
