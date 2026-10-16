import 'killer_cage.dart';
import 'sudoku_board.dart';
import 'sudoku_pos.dart';
import 'variant.dart';

/// Sudoku validation logic for Classic, X-Sudoku and Killer variants.
class SudokuRules {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Whether placing [value] at (row,col) is conflict-free.
  static bool isLegal(SudokuBoard board, int row, int col, int value) =>
      _isLegalGrid(board.toGrid(), row, col, value, board.variant, board.cages);

  /// Whether the board is completely and correctly filled.
  static bool isComplete(SudokuBoard board) {
    if (!board.isComplete) return false;
    final grid = board.toGrid();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = grid[r][c]!;
        // Temporarily clear the cell so we check conflicts with others.
        grid[r][c] = null;
        if (!_isLegalGrid(grid, r, c, v, board.variant, board.cages)) {
          return false;
        }
        grid[r][c] = v;
      }
    }
    return true;
  }

  /// Positions that conflict with (row,col)'s current value.
  static Set<SudokuPos> conflictingCells(SudokuBoard board, int row, int col) {
    final v = board.cells[row][col].value;
    if (v == null) return {};

    final result = <SudokuPos>{};
    _collectConflicts(board.toGrid(), row, col, v, board.variant, board.cages, result);
    return result;
  }

  /// All cells that share a constraint group with (row,col).
  static Set<SudokuPos> peersOf(
    int row,
    int col,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final peers = <SudokuPos>{};
    // Row + col + box
    for (int c = 0; c < 9; c++) {
      if (c != col) peers.add(SudokuPos(row, c));
    }
    for (int r = 0; r < 9; r++) {
      if (r != row) peers.add(SudokuPos(r, col));
    }
    final boxR = (row ~/ 3) * 3, boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if (r != row || c != col) peers.add(SudokuPos(r, c));
      }
    }
    // X-Sudoku diagonals
    if (variant == SudokuVariant.xSudoku) {
      if (row == col) {
        for (int i = 0; i < 9; i++) {
          if (i != row) peers.add(SudokuPos(i, i));
        }
      }
      if (row + col == 8) {
        for (int i = 0; i < 9; i++) {
          if (i != row) peers.add(SudokuPos(i, 8 - i));
        }
      }
    }
    // Killer cage
    if (variant == SudokuVariant.killer && cages != null) {
      final cage = _cageOf(cages, row, col);
      if (cage != null) {
        for (final p in cage.cells) {
          if (p.row != row || p.col != col) peers.add(p);
        }
      }
    }
    return peers;
  }

  /// Whether (row,col) is on the main or anti diagonal (for X-Sudoku highlight).
  static bool isOnDiagonal(int row, int col) => row == col || row + col == 8;

  // ── Internal helpers ───────────────────────────────────────────────────────

  static bool _isLegalGrid(
    List<List<int?>> grid,
    int row,
    int col,
    int value,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    // Row
    for (int c = 0; c < 9; c++) {
      if (c != col && grid[row][c] == value) return false;
    }
    // Col
    for (int r = 0; r < 9; r++) {
      if (r != row && grid[r][col] == value) return false;
    }
    // Box
    final boxR = (row ~/ 3) * 3, boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if ((r != row || c != col) && grid[r][c] == value) return false;
      }
    }
    // X-Sudoku diagonals
    if (variant == SudokuVariant.xSudoku) {
      if (row == col) {
        for (int i = 0; i < 9; i++) {
          if (i != row && grid[i][i] == value) return false;
        }
      }
      if (row + col == 8) {
        for (int i = 0; i < 9; i++) {
          if (i != row && grid[i][8 - i] == value) return false;
        }
      }
    }
    // Killer cage
    if (variant == SudokuVariant.killer && cages != null) {
      final cage = _cageOf(cages, row, col);
      if (cage != null) {
        // No repeat within cage
        for (final p in cage.cells) {
          if ((p.row != row || p.col != col) && grid[p.row][p.col] == value) {
            return false;
          }
        }
        // Sum feasibility
        int placed = value, empty = 0;
        for (final p in cage.cells) {
          if (p.row == row && p.col == col) continue;
          final v = grid[p.row][p.col];
          if (v != null) {
            placed += v;
          } else {
            empty++;
          }
        }
        if (empty == 0) {
          if (placed != cage.sum) return false;
        } else {
          if (placed + empty > cage.sum) return false;
          if (placed + empty * 9 < cage.sum) return false;
        }
      }
    }
    return true;
  }

  static void _collectConflicts(
    List<List<int?>> grid,
    int row,
    int col,
    int value,
    SudokuVariant variant,
    List<KillerCage>? cages,
    Set<SudokuPos> out,
  ) {
    for (int c = 0; c < 9; c++) {
      if (c != col && grid[row][c] == value) out.add(SudokuPos(row, c));
    }
    for (int r = 0; r < 9; r++) {
      if (r != row && grid[r][col] == value) out.add(SudokuPos(r, col));
    }
    final boxR = (row ~/ 3) * 3, boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if ((r != row || c != col) && grid[r][c] == value) out.add(SudokuPos(r, c));
      }
    }
    if (variant == SudokuVariant.xSudoku) {
      if (row == col) {
        for (int i = 0; i < 9; i++) {
          if (i != row && grid[i][i] == value) out.add(SudokuPos(i, i));
        }
      }
      if (row + col == 8) {
        for (int i = 0; i < 9; i++) {
          if (i != row && grid[i][8 - i] == value) out.add(SudokuPos(i, 8 - i));
        }
      }
    }
    if (variant == SudokuVariant.killer && cages != null) {
      final cage = _cageOf(cages, row, col);
      if (cage != null) {
        for (final p in cage.cells) {
          if ((p.row != row || p.col != col) && grid[p.row][p.col] == value) {
            out.add(p);
          }
        }
      }
    }
  }

  static KillerCage? _cageOf(List<KillerCage> cages, int row, int col) {
    for (final cage in cages) {
      for (final p in cage.cells) {
        if (p.row == row && p.col == col) return cage;
      }
    }
    return null;
  }

  // ── Grid-level helpers (used by solver/generator) ─────────────────────────

  /// Candidates for (row,col) given a raw int grid.
  static Set<int> candidatesFor(
    List<List<int?>> grid,
    int row,
    int col,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    if (grid[row][col] != null) return {};
    final result = <int>{};
    for (int v = 1; v <= 9; v++) {
      if (_isLegalGrid(grid, row, col, v, variant, cages)) result.add(v);
    }
    return result;
  }

  /// Returns [_isLegalGrid] so solver/generator can use the same logic.
  static bool isLegalGrid(
    List<List<int?>> grid,
    int row,
    int col,
    int value,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) =>
      _isLegalGrid(grid, row, col, value, variant, cages);
}
