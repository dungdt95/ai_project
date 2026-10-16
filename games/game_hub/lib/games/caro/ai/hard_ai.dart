import 'dart:isolate';
import '../domain/board.dart';
import '../domain/move.dart';
import 'ai_engine.dart';

/// Hard AI: Minimax + Alpha-Beta pruning at depth 4, runs in an Isolate.
class HardAi implements AiEngine {
  static const _depth = 4;

  @override
  Future<Move> chooseMove(
    Board board,
    Player currentPlayer,
    Duration timeLimit,
  ) {
    return Isolate.run(() => _compute(board, currentPlayer));
  }

  static Move _compute(Board board, Player currentPlayer) {
    final candidates = _orderedCandidates(board, currentPlayer);
    Position best = candidates.first;
    int bestScore = -1 << 30;

    for (final pos in candidates) {
      final newBoard = board.applyMove(
        Move(position: pos, player: currentPlayer, timestamp: DateTime.now()),
      );
      final score = _minimax(
        newBoard,
        currentPlayer.opponent,
        _depth - 1,
        -PatternScore.win * 2,
        PatternScore.win * 2,
        currentPlayer,
      );
      if (score > bestScore) {
        bestScore = score;
        best = pos;
      }
    }
    return Move(position: best, player: currentPlayer, timestamp: DateTime.now());
  }

  static int _minimax(
    Board board,
    Player current,
    int depth,
    int alpha,
    int beta,
    Player maximizingPlayer,
  ) {
    final score = evaluateBoard(board, maximizingPlayer);
    if (score.abs() >= PatternScore.win || depth == 0) return score;

    final candidates = _orderedCandidates(board, current);
    if (candidates.isEmpty) return score;

    if (current == maximizingPlayer) {
      int best = -PatternScore.win * 2;
      for (final pos in candidates) {
        final nb = board.applyMove(
          Move(position: pos, player: current, timestamp: DateTime.now()),
        );
        best = _max(best, _minimax(nb, current.opponent, depth - 1, alpha, beta, maximizingPlayer));
        alpha = _max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = PatternScore.win * 2;
      for (final pos in candidates) {
        final nb = board.applyMove(
          Move(position: pos, player: current, timestamp: DateTime.now()),
        );
        best = _min(best, _minimax(nb, current.opponent, depth - 1, alpha, beta, maximizingPlayer));
        beta = _min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  static List<Position> _orderedCandidates(Board board, Player player) {
    final candidates = candidateMoves(board);
    candidates.sort((a, b) {
      final sa = scorePosition(board, a, player) +
          scorePosition(board, a, player.opponent);
      final sb = scorePosition(board, b, player) +
          scorePosition(board, b, player.opponent);
      return sb.compareTo(sa);
    });
    // Limit to top 15 for performance.
    return candidates.take(15).toList();
  }

  static int _max(int a, int b) => a > b ? a : b;
  static int _min(int a, int b) => a < b ? a : b;
}
