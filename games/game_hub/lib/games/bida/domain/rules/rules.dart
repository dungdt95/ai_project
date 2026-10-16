import '../ball.dart';
import '../game_state.dart';
import '../shot_result.dart';

abstract class BidaRules {
  /// Returns updated state after evaluating a shot result.
  BidaGameState evaluate(BidaGameState state, ShotResult result);

  /// Returns true when the game is finished.
  bool isGameOver(BidaGameState state);

  /// Returns initial ball layout.
  List<Ball> rackBalls();
}
