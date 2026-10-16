import 'package:flame/components.dart';
import '../ball.dart';
import '../game_state.dart';
import '../shot_result.dart';
import '../table.dart';
import 'rules.dart';

class EightBallRules extends BidaRules {
  @override
  List<Ball> rackBalls() {
    final balls = <Ball>[];

    balls.add(Ball(
      id: 0, type: BallType.cue, number: 0,
      position: BidaTable.headSpot.clone(),
    ));

    // Standard WPA triangle rack — 1 at apex, 8 in middle
    final rackOrder = [1, 9, 2, 10, 8, 3, 14, 11, 7, 4, 6, 13, 15, 12, 5];
    final fp = BidaTable.footSpot;
    final r = Ball.radiusM * 2 + 0.002;

    var idx = 0;
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col <= row; col++) {
        final n = rackOrder[idx++];
        final x = fp.x + row * r * 0.866;
        final y = fp.y - row * r / 2 + col * r;
        balls.add(Ball(
          id: n, number: n,
          type: n == 8 ? BallType.eight : (n <= 7 ? BallType.solid : BallType.stripe),
          position: Vector2(x, y),
        ));
      }
    }
    return balls;
  }

  @override
  BidaGameState evaluate(BidaGameState state, ShotResult result) {
    final pocketed = result.pocketedIds;
    final isFoul = _checkFoul(state, result);

    // Increment shot counter
    var newState = state.copyWith(shotCount: state.shotCount + 1);

    // Mark non-cue pocketed balls as pocketed regardless of foul
    for (final b in newState.balls) {
      if (pocketed.contains(b.id) && b.id != 0) b.isPocketed = true;
    }

    // 8-ball pocketed always ends the game — check before foul so we never
    // skip this when the foul branch would return early.
    if (pocketed.contains(8)) {
      final group = state.playerGroups[state.currentPlayer];
      final myBalls = _myBalls(state);
      // Legal win: cleared own group, no foul on this shot
      final isLegalWin = myBalls.isEmpty && group != PlayerGroup.none && !isFoul;
      final winner = isLegalWin ? state.currentPlayer : 1 - state.currentPlayer;
      return newState.copyWith(winner: winner, phase: TurnPhase.over);
    }

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

    // Assign groups on first legal pocket
    List<PlayerGroup>? assignedGroups;
    bool? groupAssigned;
    if (!state.isGroupAssigned && pocketed.isNotEmpty) {
      final firstPocketed = state.balls.firstWhere(
        (b) => b.id == pocketed.first,
        orElse: () => state.balls.first,
      );
      if (firstPocketed.type == BallType.solid || firstPocketed.type == BallType.stripe) {
        final myGroup = firstPocketed.type == BallType.solid ? PlayerGroup.solid : PlayerGroup.stripe;
        final oppGroup = myGroup == PlayerGroup.solid ? PlayerGroup.stripe : PlayerGroup.solid;
        assignedGroups = List.of(state.playerGroups);
        assignedGroups[state.currentPlayer] = myGroup;
        assignedGroups[1 - state.currentPlayer] = oppGroup;
        groupAssigned = true;
      }
    }

    String? assignMsg;
    if (assignedGroups != null) {
      newState = newState.copyWith(
        playerGroups: assignedGroups,
        isGroupAssigned: groupAssigned,
      );
      final p0 = assignedGroups![0] == PlayerGroup.solid ? 'Đặc (1-7)' : 'Sọc (9-15)';
      final p1 = assignedGroups[1] == PlayerGroup.solid ? 'Đặc (1-7)' : 'Sọc (9-15)';
      assignMsg = 'P1: $p0  |  P2: $p1';
    }

    // Continue turn if scored own balls, else switch
    final scoredOwn = _scoredOwnBalls(newState, pocketed);
    if (!scoredOwn) {
      return newState.copyWith(
        currentPlayer: 1 - state.currentPlayer,
        message: assignMsg,
        clearMessage: assignMsg == null,
      );
    }
    return newState.copyWith(message: assignMsg ?? 'Tiếp tục đánh!');
  }

  @override
  bool isGameOver(BidaGameState state) => state.winner != null;

  bool _checkFoul(BidaGameState state, ShotResult result) {
    if (result.cueBallScratched) return true;
    if (result.noBallHit) return true;
    if (result.ballsLeftTableIds.isNotEmpty) return true;

    if (state.isGroupAssigned && result.firstBallHitId != null) {
      final firstBall = state.balls.firstWhere((b) => b.id == result.firstBallHitId);
      final myGroup = state.playerGroups[state.currentPlayer];
      final myBallsLeft = _myBalls(state);
      if (myBallsLeft.isEmpty) {
        // Must hit 8-ball first when own group is cleared
        if (firstBall.type != BallType.eight) return true;
      } else {
        if (myGroup == PlayerGroup.solid && firstBall.type != BallType.solid) return true;
        if (myGroup == PlayerGroup.stripe && firstBall.type != BallType.stripe) return true;
      }
    }
    return false;
  }

  List<Ball> _myBalls(BidaGameState state) {
    final myGroup = state.playerGroups[state.currentPlayer];
    final targetType = myGroup == PlayerGroup.solid ? BallType.solid : BallType.stripe;
    return state.activeBalls.where((b) => b.type == targetType).toList();
  }

  bool _scoredOwnBalls(BidaGameState state, List<int> pocketedIds) {
    if (pocketedIds.isEmpty) return false;
    if (!state.isGroupAssigned) return true; // before assignment any pocket continues
    final myGroup = state.playerGroups[state.currentPlayer];
    final targetType = myGroup == PlayerGroup.solid ? BallType.solid : BallType.stripe;
    return pocketedIds.any((id) {
      final b = state.balls.firstWhere((ball) => ball.id == id, orElse: () => state.balls.first);
      return b.type == targetType;
    });
  }
}
