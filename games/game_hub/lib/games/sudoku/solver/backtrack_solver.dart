import '../domain/killer_cage.dart';
import '../domain/rules.dart';
import '../domain/variant.dart';

/// Brute-force backtracking solver.  Used for:
///  • Generating a full valid board.
///  • Verifying puzzle uniqueness (count solutions ≤ 2).
class BacktrackSolver {
  /// Returns the number of solutions found, stopping at [limit] (default 2).
  static int countSolutions(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages, {
    int limit = 2,
  }) {
    int count = 0;
    _solve(
      _copy(grid),
      variant,
      cages,
      (s) {
        count++;
        return count < limit;
      },
    );
    return count;
  }

  /// True if the puzzle has exactly one solution.
  static bool hasUniqueSolution(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) =>
      countSolutions(grid, variant, cages) == 1;

  /// Solves [grid] in place, returns true if a solution was found.
  static bool solveInPlace(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    bool solved = false;
    _solve(grid, variant, cages, (_) {
      solved = true;
      return false;
    });
    return solved;
  }

  /// Returns a solved copy of [grid], or null if unsolvable.
  static List<List<int>>? solve(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final copy = _copy(grid);
    if (solveInPlace(copy, variant, cages)) {
      return List.generate(9, (r) => List.generate(9, (c) => copy[r][c]!));
    }
    return null;
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static void _solve(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
    bool Function(List<List<int?>>) onSolution,
  ) {
    // MRV: pick the empty cell with fewest valid candidates.
    int? bestRow, bestCol, bestCount;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] != null) continue;
        int cnt = 0;
        for (int v = 1; v <= 9; v++) {
          if (SudokuRules.isLegalGrid(grid, r, c, v, variant, cages)) cnt++;
        }
        if (cnt == 0) return; // dead end
        if (bestCount == null || cnt < bestCount) {
          bestCount = cnt;
          bestRow = r;
          bestCol = c;
        }
      }
    }

    if (bestRow == null || bestCol == null) {
      onSolution(grid); // all cells filled
      return;
    }

    for (int v = 1; v <= 9; v++) {
      if (!SudokuRules.isLegalGrid(grid, bestRow, bestCol, v, variant, cages)) {
        continue;
      }
      grid[bestRow][bestCol] = v;
      bool keepGoing = true;
      _solve(grid, variant, cages, (s) {
        keepGoing = onSolution(s);
        return keepGoing;
      });
      if (!keepGoing) return;
      grid[bestRow][bestCol] = null;
    }
  }

  static List<List<int?>> _copy(List<List<int?>> g) =>
      List.generate(9, (r) => List<int?>.from(g[r]));
}
