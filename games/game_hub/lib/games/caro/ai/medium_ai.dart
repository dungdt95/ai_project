import '../domain/board.dart';
import '../domain/move.dart';
import 'ai_engine.dart';

/// Medium AI: greedy 1-ply heuristic — picks the highest-scoring candidate.
class MediumAi implements AiEngine {
  @override
  Future<Move> chooseMove(
    Board board,
    Player currentPlayer,
    Duration timeLimit,
  ) async {
    final candidates = candidateMoves(board, radius: 2);
    Position best = candidates.first;
    int bestScore = -1 << 30;

    for (final pos in candidates) {
      final myScore = scorePosition(board, pos, currentPlayer);
      final oppScore =
          scorePosition(board, pos, currentPlayer.opponent) * 11 ~/ 10;
      final score = myScore > oppScore ? myScore : oppScore;
      if (score > bestScore) {
        bestScore = score;
        best = pos;
      }
    }

    return Move(position: best, player: currentPlayer, timestamp: DateTime.now());
  }
}
