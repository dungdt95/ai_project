import 'dart:math';
import 'package:flame/components.dart';
import '../ball.dart';
import '../game_state.dart';
import '../shot_result.dart';
import '../table.dart';
import 'rules.dart';

/// Vietnamese pool (Bida Lỗ VN): 10-ball rotation.
/// Must hit lowest-numbered ball first; pocket ball #10 legally to win.
class VnBallRules extends BidaRules {
  @override
  List<Ball> rackBalls() {
    final balls = <Ball>[];

    balls.add(Ball(
      id: 0, type: BallType.cue, number: 0,
      position: BidaTable.headSpot.clone(),
    ));

    // Triangle rack: 1 at apex, 10 in back-centre, rest random
    final others = [2, 3, 4, 5, 6, 7, 8, 9]..shuffle();
    // 4 rows: 1  |  2  |  3  |  4 balls
    // rackOrder indices → positions below
    final rackOrder = [
      1,                                       // row 0 (apex)
      others[0], others[1],                   // row 1
      others[2], others[3], others[4],        // row 2
      others[5], others[6], others[7], 10,    // row 3 — 10 at far end
    ];

    const d = Ball.radiusM * 2 + 0.002;
    const h = d * 0.866;
    final fp = BidaTable.footSpot;

    final positions = [
      // Row 0 (1 ball)
      fp.clone(),
      // Row 1 (2 balls)
      Vector2(fp.x + h, fp.y - d * 0.5),
      Vector2(fp.x + h, fp.y + d * 0.5),
      // Row 2 (3 balls)
      Vector2(fp.x + h * 2, fp.y - d),
      Vector2(fp.x + h * 2, fp.y),
      Vector2(fp.x + h * 2, fp.y + d),
      // Row 3 (4 balls)
      Vector2(fp.x + h * 3, fp.y - d * 1.5),
      Vector2(fp.x + h * 3, fp.y - d * 0.5),
      Vector2(fp.x + h * 3, fp.y + d * 0.5),
      Vector2(fp.x + h * 3, fp.y + d * 1.5),
    ];

    for (int i = 0; i < rackOrder.length; i++) {
      final n = rackOrder[i];
      balls.add(Ball(
        id: n, number: n,
        type: BallType.solid,
        position: positions[i],
      ));
    }
    return balls;
  }

  @override
  BidaGameState evaluate(BidaGameState state, ShotResult result) {
    final pocketed = result.pocketedIds;
    var newState = state.copyWith(shotCount: state.shotCount + 1);

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

    // Pocket ball #10 legally → win
    if (pocketed.contains(10)) {
      return newState.copyWith(winner: state.currentPlayer, phase: TurnPhase.over);
    }

    // Track scores (number of balls pocketed per player)
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
