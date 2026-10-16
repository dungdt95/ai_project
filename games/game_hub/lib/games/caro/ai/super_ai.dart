import 'dart:isolate';
import '../domain/board.dart';
import '../domain/move.dart';
import 'ai_engine.dart';

/// Super AI: Minimax + Alpha-Beta + iterative deepening + transposition table.
/// Runs in an Isolate and respects a time limit via [timeLimit].
class SuperAi implements AiEngine {
  @override
  Future<Move> chooseMove(
    Board board,
    Player currentPlayer,
    Duration timeLimit,
  ) {
    final deadline = DateTime.now().add(timeLimit);
    return Isolate.run(() => _compute(board, currentPlayer, deadline));
  }

  static Move _compute(Board board, Player currentPlayer, DateTime deadline) {
    final candidates = _orderedCandidates(board, currentPlayer);
    Position best = candidates.first;

    // Iterative deepening: increase depth until time runs out.
    for (int depth = 2; depth <= 8; depth++) {
      if (DateTime.now().isAfter(deadline)) break;
      Position? depthBest;
      int bestScore = -PatternScore.win * 2;
      final tt = <int, _TTEntry>{};

      for (final pos in candidates) {
        if (DateTime.now().isAfter(deadline)) break;
        final nb = board.applyMove(
          Move(position: pos, player: currentPlayer, timestamp: DateTime.now()),
        );
        final score = _alphabeta(
          nb,
          currentPlayer.opponent,
          depth - 1,
          -PatternScore.win * 2,
          PatternScore.win * 2,
          currentPlayer,
          deadline,
          tt,
        );
        if (score > bestScore) {
          bestScore = score;
          depthBest = pos;
        }
      }
      if (depthBest != null) best = depthBest;
      if (bestScore >= PatternScore.win) break; // found forced win
    }
    return Move(position: best, player: currentPlayer, timestamp: DateTime.now());
  }

  static int _alphabeta(
    Board board,
    Player current,
    int depth,
    int alpha,
    int beta,
    Player maximizer,
    DateTime deadline,
    Map<int, _TTEntry> tt,
  ) {
    if (DateTime.now().isAfter(deadline)) return evaluateBoard(board, maximizer);

    final key = _zobristHash(board, current);
    final cached = tt[key];
    if (cached != null && cached.depth >= depth) {
      if (cached.flag == _TTFlag.exact) return cached.score;
      if (cached.flag == _TTFlag.lowerBound) alpha = _max(alpha, cached.score);
      if (cached.flag == _TTFlag.upperBound) beta = _min(beta, cached.score);
      if (alpha >= beta) return cached.score;
    }

    final boardScore = evaluateBoard(board, maximizer);
    if (boardScore.abs() >= PatternScore.win || depth == 0) return boardScore;

    final candidates = _orderedCandidates(board, current);
    if (candidates.isEmpty) return boardScore;

    final origAlpha = alpha;
    int best = current == maximizer ? (-PatternScore.win * 2) : (PatternScore.win * 2);

    for (final pos in candidates) {
      final nb = board.applyMove(
        Move(position: pos, player: current, timestamp: DateTime.now()),
      );
      final score = _alphabeta(nb, current.opponent, depth - 1, alpha, beta, maximizer, deadline, tt);
      if (current == maximizer) {
        best = _max(best, score);
        alpha = _max(alpha, best);
      } else {
        best = _min(best, score);
        beta = _min(beta, best);
      }
      if (beta <= alpha) break;
    }

    final flag = best <= origAlpha
        ? _TTFlag.upperBound
        : best >= beta
            ? _TTFlag.lowerBound
            : _TTFlag.exact;
    tt[key] = _TTEntry(score: best, depth: depth, flag: flag);

    return best;
  }

  static List<Position> _orderedCandidates(Board board, Player player) {
    final candidates = candidateMoves(board, radius: 2);
    candidates.sort((a, b) {
      final sa = scorePosition(board, a, player) +
          scorePosition(board, a, player.opponent) * 11 ~/ 10;
      final sb = scorePosition(board, b, player) +
          scorePosition(board, b, player.opponent) * 11 ~/ 10;
      return sb.compareTo(sa);
    });
    return candidates.take(12).toList();
  }

  static int _zobristHash(Board board, Player current) {
    int h = current == Player.x ? 0x12345678 : 0x87654321;
    for (int r = 0; r < board.size; r++) {
      for (int c = 0; c < board.size; c++) {
        final cell = board.cells[r][c];
        if (cell == Player.x) h ^= (r * 31 + c) * 0x9E3779B9;
        if (cell == Player.o) h ^= (r * 31 + c) * 0x6C62272E;
      }
    }
    return h;
  }

  static int _max(int a, int b) => a > b ? a : b;
  static int _min(int a, int b) => a < b ? a : b;
}

enum _TTFlag { exact, lowerBound, upperBound }

class _TTEntry {
  const _TTEntry({required this.score, required this.depth, required this.flag});
  final int score;
  final int depth;
  final _TTFlag flag;
}
