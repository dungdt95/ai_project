import 'board.dart';
import 'move.dart';

/// Implements Vietnamese Caro rules:
/// - Win: exactly 5 consecutive stones NOT blocked on both ends.
/// - 6+ in a row does NOT count as a win.
/// - Draw: all cells filled with no winner.
class CaroRules {
  static const _dirs = [
    (1, 0),  // vertical
    (0, 1),  // horizontal
    (1, 1),  // diagonal ↘
    (1, -1), // diagonal ↙
  ];

  /// Returns a winning line of 5 [Position]s if [player] has won, else null.
  static List<Position>? findWinningLine(Board board, Player player) {
    for (int r = 0; r < board.size; r++) {
      for (int c = 0; c < board.size; c++) {
        if (board.cells[r][c] != player) continue;
        for (final (dr, dc) in _dirs) {
          final line = _checkLine(board, r, c, dr, dc, player);
          if (line != null) return line;
        }
      }
    }
    return null;
  }

  /// Checks starting at (r,c) in direction (dr,dc).
  /// Returns the 5-position line if it's a valid win, else null.
  static List<Position>? _checkLine(
    Board board, int r, int c, int dr, int dc, Player player,
  ) {
    // Only process the head of a run (previous cell must be empty or OOB or opponent).
    final pr = r - dr;
    final pc = c - dc;
    if (board.isInBounds(pr, pc) && board.cells[pr][pc] == player) return null;

    // Count consecutive stones.
    final line = <Position>[];
    int cr = r, cc = c;
    while (board.isInBounds(cr, cc) && board.cells[cr][cc] == player) {
      line.add(Position(cr, cc));
      cr += dr;
      cc += dc;
    }

    if (line.length != 5) return null; // exactly 5 required

    // Check: the cell before the start must not be empty (already checked above as OOB/opponent).
    // Check: the cell after the end must not be opponent (it can be empty or OOB — open end).
    // Vietnamese rule: win only if NOT blocked on BOTH ends.
    final beforeBlocked = !board.isInBounds(pr, pc) ||
        board.cells[pr][pc] == player.opponent;
    final afterBlocked = !board.isInBounds(cr, cc) ||
        board.cells[cr][cc] == player.opponent;

    if (beforeBlocked && afterBlocked) return null; // blocked both ends → no win
    return line;
  }

  /// Evaluates the board after [lastMove] was placed and returns the updated status.
  static GameStatus evaluate(Board board, Move lastMove) {
    final line = findWinningLine(board, lastMove.player);
    if (line != null) {
      return lastMove.player == Player.x ? GameStatus.xWon : GameStatus.oWon;
    }
    // Draw: no empty cells.
    final full = board.cells.every((row) => row.every((c) => c != null));
    return full ? GameStatus.draw : GameStatus.playing;
  }

  /// Returns true if placing at [pos] is legal (in bounds + empty + game not over).
  static bool isLegalMove(Board board, Position pos) {
    if (board.isOver) return false;
    if (!board.isInBounds(pos.row, pos.col)) return false;
    return board.isEmpty(pos.row, pos.col);
  }
}
