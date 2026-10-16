import 'package:flame/components.dart';
import '../ball.dart';
import '../game_state.dart';
import '../shot_result.dart';
import '../table.dart';
import 'rules.dart';

/// 3-cushion carom: 3 balls, no pockets.
/// Score a point by making the cue ball touch ≥3 cushions AND both object balls in one shot.
/// First to [_pointsToWin] wins.
class CaromRules extends BidaRules {
  static const int _pointsToWin = 15;

  @override
  List<Ball> rackBalls() {
    final cx = BidaTable.widthM * 0.5;
    final cy = BidaTable.heightM * 0.5;
    return [
      Ball(id: 0, type: BallType.cue,        number: 0, position: Vector2(cx * 0.5, cy)),
      Ball(id: 1, type: BallType.caromYellow, number: 1, position: Vector2(cx, cy - 0.15)),
      Ball(id: 2, type: BallType.caromRed,    number: 2, position: Vector2(cx, cy + 0.15)),
    ];
  }

  @override
  bool isGameOver(BidaGameState state) =>
      state.scores[0] >= _pointsToWin || state.scores[1] >= _pointsToWin;

  @override
  BidaGameState evaluate(BidaGameState state, ShotResult result) {
    final next = state.copyWith(shotCount: state.shotCount + 1, clearMessage: true);

    // Foul: cue ball left table
    if (result.ballsLeftTableIds.contains(0)) {
      return _foul(next, 'Bi trắng ra ngoài bàn!');
    }

    // Must contact both object balls
    if (result.firstBallHitId == null) {
      return _foul(next, 'Không chạm bi nào!');
    }
    if (result.secondBallHitId == null) {
      return _foul(next, 'Phải chạm cả 2 bi!');
    }

    // Must have ≥3 cushion hits by the cue ball before second object ball
    if (result.cueCushionCountBeforeSecondBall < 3) {
      return _foul(next, '3 băng: chỉ ${result.cueCushionCountBeforeSecondBall} băng!');
    }

    // Point scored — same player continues
    final newScores = List<int>.from(next.scores);
    newScores[next.currentPlayer]++;
    final scored = next.copyWith(scores: newScores);

    if (scored.scores[scored.currentPlayer] >= _pointsToWin) {
      return scored.copyWith(
        phase: TurnPhase.over,
        winner: scored.currentPlayer,
        message: 'Người chơi ${scored.currentPlayer + 1} thắng!',
      );
    }

    return scored.copyWith(
      message: '+ 1 điểm! Tiếp tục đánh',
    );
  }

  BidaGameState _foul(BidaGameState state, String msg) {
    final newFouls = state.fouls + 1;
    final nextPlayer = 1 - state.currentPlayer;
    return state.copyWith(
      currentPlayer: nextPlayer,
      fouls: newFouls,
      message: msg,
    );
  }
}
