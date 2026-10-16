import '../domain/board.dart';
import '../domain/move.dart';

/// Interface every AI difficulty must implement.
abstract class AiEngine {
  /// Returns the best move for [currentPlayer] within [timeLimit].
  Future<Move> chooseMove(
    Board board,
    Player currentPlayer,
    Duration timeLimit,
  );
}

/// Score table for pattern evaluation.
class PatternScore {
  static const int win = 100000000;
  static const int open4 = 10000;
  static const int closed4 = 1000;
  static const int open3 = 1000;
  static const int closed3 = 100;
  static const int open2 = 100;
  static const int open1 = 10;
}

/// Shared utility: generates candidate moves within [radius] of placed stones.
List<Position> candidateMoves(Board board, {int radius = 2}) {
  if (board.history.isEmpty) {
    final center = board.size ~/ 2;
    return [Position(center, center)];
  }
  final visited = <Position>{};
  for (final m in board.history) {
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final r = m.position.row + dr;
        final c = m.position.col + dc;
        final p = Position(r, c);
        if (board.isInBounds(r, c) && board.isEmpty(r, c) && !visited.contains(p)) {
          visited.add(p);
        }
      }
    }
  }
  return visited.toList();
}

/// Evaluates a single direction for a given player on the board.
/// Returns a heuristic score contribution.
int evalDirection(
  Board board,
  int r,
  int c,
  int dr,
  int dc,
  Player player,
) {
  final opponent = player.opponent;
  int count = 0;
  bool openBefore = false;
  bool openAfter = false;

  // look backward
  int br = r - dr, bc = c - dc;
  if (!board.isInBounds(br, bc) || board.cells[br][bc] == opponent) {
    openBefore = false;
  } else if (board.cells[br][bc] == null) {
    openBefore = true;
  }

  // count forward
  int cr = r, cc = c;
  while (board.isInBounds(cr, cc) && board.cells[cr][cc] == player) {
    count++;
    cr += dr;
    cc += dc;
  }

  if (!board.isInBounds(cr, cc) || board.cells[cr][cc] == opponent) {
    openAfter = false;
  } else {
    openAfter = board.cells[cr][cc] == null;
  }

  if (count >= 5) {
    // Check if it's a valid win (not both blocked).
    if (!openBefore && !openAfter) return 0;
    return PatternScore.win;
  }
  if (count == 4) {
    if (openBefore && openAfter) return PatternScore.open4;
    if (openBefore || openAfter) return PatternScore.closed4;
    return 0;
  }
  if (count == 3) {
    if (openBefore && openAfter) return PatternScore.open3;
    if (openBefore || openAfter) return PatternScore.closed3;
    return 0;
  }
  if (count == 2) return openBefore && openAfter ? PatternScore.open2 : 0;
  if (count == 1) return openBefore && openAfter ? PatternScore.open1 : 0;
  return 0;
}

const _evalDirs = [(1, 0), (0, 1), (1, 1), (1, -1)];

/// Heuristic score for placing [player]'s stone at [pos] (pos must be empty).
/// Counts consecutive friendly stones in both directions from pos, adds 1 for pos.
int scorePosition(Board board, Position pos, Player player) {
  int score = 0;
  final opp = player.opponent;
  for (final (dr, dc) in _evalDirs) {
    int count = 1; // the stone being placed
    bool openBefore = false, openAfter = false;

    // Count backward.
    int r = pos.row - dr, c = pos.col - dc;
    while (board.isInBounds(r, c) && board.cells[r][c] == player) {
      count++;
      r -= dr;
      c -= dc;
    }
    openBefore =
        board.isInBounds(r, c) && board.cells[r][c] != opp;

    // Count forward.
    r = pos.row + dr;
    c = pos.col + dc;
    while (board.isInBounds(r, c) && board.cells[r][c] == player) {
      count++;
      r += dr;
      c += dc;
    }
    openAfter =
        board.isInBounds(r, c) && board.cells[r][c] != opp;

    score += _lineScore(count, openBefore, openAfter);
  }
  return score;
}

int _lineScore(int count, bool openBefore, bool openAfter) {
  if (count >= 5) {
    if (!openBefore && !openAfter) return 0; // both blocked = no win
    return PatternScore.win;
  }
  if (count == 4) {
    if (openBefore && openAfter) return PatternScore.open4;
    if (openBefore || openAfter) return PatternScore.closed4;
    return 0;
  }
  if (count == 3) {
    if (openBefore && openAfter) return PatternScore.open3;
    if (openBefore || openAfter) return PatternScore.closed3;
    return 0;
  }
  if (count == 2) return openBefore && openAfter ? PatternScore.open2 : 0;
  if (count == 1) return openBefore && openAfter ? PatternScore.open1 : 0;
  return 0;
}

/// Full board evaluation: player's score minus opponent's (weighted).
int evaluateBoard(Board board, Player player) {
  int myScore = 0, oppScore = 0;
  final opp = player.opponent;
  for (int r = 0; r < board.size; r++) {
    for (int c = 0; c < board.size; c++) {
      if (board.cells[r][c] == player) {
        for (final (dr, dc) in _evalDirs) {
          myScore += evalDirection(board, r, c, dr, dc, player);
        }
      } else if (board.cells[r][c] == opp) {
        for (final (dr, dc) in _evalDirs) {
          oppScore += evalDirection(board, r, c, dr, dc, opp);
        }
      }
    }
  }
  return myScore - (oppScore * 11 ~/ 10); // weight defense slightly higher
}
