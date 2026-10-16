import 'dart:math';
import '../domain/board.dart';
import '../domain/move.dart';
import '../domain/rules.dart';
import 'ai_engine.dart';

/// Easy AI: random moves near existing stones, blocks immediate winning threats only.
class EasyAi implements AiEngine {
  final _rng = Random();

  @override
  Future<Move> chooseMove(
    Board board,
    Player currentPlayer,
    Duration timeLimit,
  ) async {
    final candidates = candidateMoves(board, radius: 2);

    // Block opponent's immediate win.
    for (final pos in candidates) {
      final testBoard = board.applyMove(
        Move(position: pos, player: currentPlayer.opponent, timestamp: DateTime.now()),
      );
      final line = CaroRules.findWinningLine(testBoard, currentPlayer.opponent);
      if (line != null) {
        return Move(position: pos, player: currentPlayer, timestamp: DateTime.now());
      }
    }

    // Random pick.
    final pos = candidates[_rng.nextInt(candidates.length)];
    return Move(position: pos, player: currentPlayer, timestamp: DateTime.now());
  }
}
