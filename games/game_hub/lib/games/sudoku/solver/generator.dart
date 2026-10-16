import 'dart:math';

import '../domain/killer_cage.dart';
import '../domain/rules.dart';
import '../domain/sudoku_pos.dart';
import '../domain/variant.dart';
import 'backtrack_solver.dart';
import 'logical_solver.dart';

/// Input/output for [generatePuzzle] (top-level for compute() isolate).
class GeneratorParams {
  const GeneratorParams({
    required this.variant,
    required this.difficulty,
    required this.seed,
  });
  final int variant;   // SudokuVariant.index
  final int difficulty; // SudokuDifficulty.index
  final int seed;
}

class GeneratorOutput {
  const GeneratorOutput({
    required this.given,
    required this.solution,
    this.cages,
  });
  final List<List<int?>> given;
  final List<List<int>> solution;
  final List<KillerCage>? cages;
}

/// Top-level function for Flutter's compute() isolate.
GeneratorOutput generatePuzzle(GeneratorParams params) {
  final gen = _PuzzleGenerator(seed: params.seed);
  return gen.generate(
    variant: SudokuVariant.values[params.variant],
    difficulty: SudokuDifficulty.values[params.difficulty],
  );
}

// ── Internal generator ────────────────────────────────────────────────────────

class _PuzzleGenerator {
  _PuzzleGenerator({required int seed}) : _rng = Random(seed);
  final Random _rng;

  GeneratorOutput generate({
    required SudokuVariant variant,
    required SudokuDifficulty difficulty,
  }) {
    for (int attempt = 0; attempt < 10; attempt++) {
      final solution = _fullBoard(variant);
      if (solution == null) continue;

      List<KillerCage>? cages;
      if (variant == SudokuVariant.killer) {
        cages = _generateCages(solution);
      }

      final given = _removeCells(
        solution: solution,
        variant: variant,
        difficulty: difficulty,
        cages: cages,
      );

      // Verify difficulty rating matches target (within one level).
      final rated = LogicalSolver.rateDifficulty(given, variant, cages);
      if ((rated.index - difficulty.index).abs() <= 1) {
        return GeneratorOutput(given: given, solution: solution, cages: cages);
      }
    }

    // Fallback: return best effort without difficulty check.
    final solution = _fullBoard(variant) ??
        List.generate(9, (r) => List.generate(9, (c) => (r * 3 + r ~/ 3 + c) % 9 + 1));
    List<KillerCage>? cages;
    if (variant == SudokuVariant.killer) cages = _generateCages(solution);
    final given = _removeCells(
      solution: solution,
      variant: variant,
      difficulty: difficulty,
      cages: cages,
    );
    return GeneratorOutput(given: given, solution: solution, cages: cages);
  }

  // ── Full board generation ─────────────────────────────────────────────────

  List<List<int>>? _fullBoard(SudokuVariant variant) {
    final grid = List.generate(9, (_) => List<int?>.filled(9, null));

    if (variant != SudokuVariant.xSudoku) {
      // Pre-fill diagonal 3×3 boxes (independent, makes backtracking faster).
      for (int b = 0; b < 3; b++) {
        _fillBox(grid, b * 3, b * 3);
      }
    }

    final shuffled = List.generate(9, (i) => i + 1)..shuffle(_rng);
    if (!BacktrackSolver.solveInPlace(grid, variant, null)) return null;
    // Shuffle solution values to get variety.
    final perm = shuffled;
    final sol = List.generate(
      9,
      (r) => List.generate(9, (c) => perm[grid[r][c]! - 1]),
    );
    // Validate shuffle result.
    final check = List.generate(9, (r) => List<int?>.from(sol[r]));
    if (!_isValidComplete(check, variant)) {
      // Fallback without shuffle
      return List.generate(9, (r) => List.generate(9, (c) => grid[r][c]!));
    }
    return sol;
  }

  bool _isValidComplete(List<List<int?>> grid, SudokuVariant variant) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = grid[r][c];
        if (v == null) return false;
        grid[r][c] = null;
        final legal = SudokuRules.isLegalGrid(grid, r, c, v, variant, null);
        grid[r][c] = v;
        if (!legal) return false;
      }
    }
    return true;
  }

  void _fillBox(List<List<int?>> grid, int startRow, int startCol) {
    final nums = List.generate(9, (i) => i + 1)..shuffle(_rng);
    int i = 0;
    for (int r = startRow; r < startRow + 3; r++) {
      for (int c = startCol; c < startCol + 3; c++) {
        grid[r][c] = nums[i++];
      }
    }
  }

  // ── Cell removal ─────────────────────────────────────────────────────────

  List<List<int?>> _removeCells({
    required List<List<int>> solution,
    required SudokuVariant variant,
    required SudokuDifficulty difficulty,
    required List<KillerCage>? cages,
  }) {
    final puzzle = List.generate(9, (r) => List<int?>.from(solution[r]));
    final positions = [
      for (int r = 0; r < 9; r++)
        for (int c = 0; c < 9; c++) (r, c),
    ]..shuffle(_rng);

    int given = 81;
    final target = difficulty.givenTarget;

    for (final (r, c) in positions) {
      if (given <= target) break;
      final saved = puzzle[r][c];
      puzzle[r][c] = null;
      if (!BacktrackSolver.hasUniqueSolution(puzzle, variant, cages)) {
        puzzle[r][c] = saved;
      } else {
        given--;
      }
    }
    return puzzle;
  }

  // ── Killer cage generation ────────────────────────────────────────────────

  List<KillerCage> _generateCages(List<List<int>> solution) {
    final assigned = List.generate(9, (_) => List<bool>.filled(9, false));
    final cages = <KillerCage>[];

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (assigned[r][c]) continue;

        final cells = <SudokuPos>[];
        final frontier = <SudokuPos>[SudokuPos(r, c)];
        assigned[r][c] = true;
        cells.add(SudokuPos(r, c));
        final maxSize = 2 + _rng.nextInt(4); // 2–5 cells

        while (cells.length < maxSize && frontier.isNotEmpty) {
          final idx = _rng.nextInt(frontier.length);
          final cur = frontier.removeAt(idx);
          for (final (dr, dc) in [
            (0, 1),
            (1, 0),
            (0, -1),
            (-1, 0),
          ]) {
            final nr = cur.row + dr, nc = cur.col + dc;
            if (nr < 0 || nr >= 9 || nc < 0 || nc >= 9) continue;
            if (assigned[nr][nc]) continue;
            assigned[nr][nc] = true;
            final np = SudokuPos(nr, nc);
            cells.add(np);
            frontier.add(np);
            if (cells.length >= maxSize) break;
          }
        }

        final sum = cells.fold(0, (s, p) => s + solution[p.row][p.col]);
        cages.add(KillerCage(cells: cells, sum: sum));
      }
    }
    return cages;
  }
}
