import '../domain/killer_cage.dart';
import '../domain/rules.dart';
import '../domain/variant.dart';
import 'backtrack_solver.dart';
import 'techniques/hidden_single.dart';
import 'techniques/locked_candidates.dart';
import 'techniques/naked_pair.dart';
import 'techniques/naked_single.dart';
import 'techniques/technique.dart';
import 'techniques/x_wing.dart';

class LogicalSolverResult {
  const LogicalSolverResult({
    required this.row,
    required this.col,
    required this.value,
    required this.description,
    required this.difficulty,
  });

  final int row, col, value;
  final String description;
  final SudokuDifficulty difficulty;
}

/// Step-by-step logical solver used for hints and difficulty rating.
class LogicalSolver {
  static final _techniques = <SolvingTechnique>[
    NakedSingle(),
    HiddenSingle(),
    LockedCandidates(),
    NakedPair(),
    XWing(),
  ];

  /// Returns the next logical step for the grid, or null if no technique applies.
  /// Falls back to the backtrack solver for Expert-level moves.
  static LogicalSolverResult? nextStep(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final cands = _buildCandidates(grid, variant, cages);

    for (final technique in _techniques) {
      // Clone candidates so eliminations in failed techniques don't persist.
      final clonedCands = _cloneCandidates(cands);
      final result = technique.apply(grid, clonedCands, variant, cages);
      if (result != null) {
        // Persist the eliminations from this technique.
        _applyEliminations(cands, clonedCands);
        return LogicalSolverResult(
          row: result.row,
          col: result.col,
          value: result.value,
          description: result.description,
          difficulty: result.difficulty,
        );
      }
    }

    // Fallback: use backtrack to give a valid placement.
    return _backtrackHint(grid, variant, cages);
  }

  /// Rates the difficulty of [grid] (the unsolved puzzle) by trying to solve it
  /// using progressively harder techniques.
  static SudokuDifficulty rateDifficulty(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final work = List.generate(9, (r) => List<int?>.from(grid[r]));
    var maxDiff = SudokuDifficulty.easy;

    int lastEmpty = -1;
    while (true) {
      final emptyCount = _countEmpty(work);
      if (emptyCount == 0) break;
      if (emptyCount == lastEmpty) {
        // Stuck — needs backtracking (expert)
        return SudokuDifficulty.expert;
      }
      lastEmpty = emptyCount;

      final cands = _buildCandidates(work, variant, cages);
      bool placed = false;
      for (final technique in _techniques) {
        final cloned = _cloneCandidates(cands);
        final result = technique.apply(work, cloned, variant, cages);
        if (result != null) {
          _applyEliminations(cands, cloned);
          work[result.row][result.col] = result.value;
          if (result.difficulty.index > maxDiff.index) {
            maxDiff = result.difficulty;
          }
          placed = true;
          break;
        }
      }
      if (!placed) return SudokuDifficulty.expert;
    }
    return maxDiff;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<List<Set<int>>> _buildCandidates(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) =>
      List.generate(
        9,
        (r) => List.generate(
          9,
          (c) => SudokuRules.candidatesFor(grid, r, c, variant, cages),
        ),
      );

  static List<List<Set<int>>> _cloneCandidates(List<List<Set<int>>> cands) =>
      List.generate(9, (r) => List.generate(9, (c) => Set<int>.from(cands[r][c])));

  static void _applyEliminations(
    List<List<Set<int>>> dest,
    List<List<Set<int>>> src,
  ) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        dest[r][c]
          ..clear()
          ..addAll(src[r][c]);
      }
    }
  }

  static int _countEmpty(List<List<int?>> grid) {
    int n = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v == null) n++;
      }
    }
    return n;
  }

  static LogicalSolverResult? _backtrackHint(
    List<List<int?>> grid,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final solution = BacktrackSolver.solve(grid, variant, cages);
    if (solution == null) return null;

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == null) {
          return LogicalSolverResult(
            row: r,
            col: c,
            value: solution[r][c],
            description: 'Gợi ý: ô ($r,$c) = ${solution[r][c]}',
            difficulty: SudokuDifficulty.expert,
          );
        }
      }
    }
    return null;
  }
}
