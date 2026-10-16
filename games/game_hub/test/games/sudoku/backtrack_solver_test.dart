import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/solver/backtrack_solver.dart';
import 'package:game_hub/games/sudoku/domain/variant.dart';

List<List<int?>> _parse(List<String> rows) =>
    rows.map((r) => r.split('').map((c) => c == '.' ? null : int.parse(c)).toList())
        .toList();

void main() {
  group('BacktrackSolver', () {
    // A valid easy puzzle with a unique solution.
    final easyPuzzle = _parse([
      '53..7....',
      '6..195...',
      '.98....6.',
      '8...6...3',
      '4..8.3..1',
      '7...2...6',
      '.6....28.',
      '...419..5',
      '....8..79',
    ]);

    test('solves a known puzzle', () {
      final grid = easyPuzzle.map((r) => List<int?>.from(r)).toList();
      final solved = BacktrackSolver.solveInPlace(grid, SudokuVariant.classic, null);
      expect(solved, isTrue);
      // Verify all cells are filled.
      for (final row in grid) {
        for (final v in row) {
          expect(v, isNotNull);
          expect(v, greaterThanOrEqualTo(1));
          expect(v, lessThanOrEqualTo(9));
        }
      }
    });

    test('detects unique solution', () {
      expect(
        BacktrackSolver.hasUniqueSolution(easyPuzzle, SudokuVariant.classic, null),
        isTrue,
      );
    });

    test('detects multiple solutions for empty board', () {
      final empty = List.generate(9, (_) => List<int?>.filled(9, null));
      final count = BacktrackSolver.countSolutions(empty, SudokuVariant.classic, null);
      expect(count, greaterThan(1));
    });

    test('solve() returns non-null for valid puzzle', () {
      final sol = BacktrackSolver.solve(easyPuzzle, SudokuVariant.classic, null);
      expect(sol, isNotNull);
      expect(sol, hasLength(9));
      expect(sol![0], hasLength(9));
    });

    test('returns null for unsolvable grid', () {
      // Row 0 has 1-8, col 8 has 9 → cell (0,8) has zero candidates.
      final bad = _parse([
        '12345678.',
        '........9',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
      ]);
      final sol = BacktrackSolver.solve(bad, SudokuVariant.classic, null);
      expect(sol, isNull);
    });
  });
}
