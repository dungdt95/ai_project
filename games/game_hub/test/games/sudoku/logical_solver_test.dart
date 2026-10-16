import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/domain/variant.dart';
import 'package:game_hub/games/sudoku/solver/logical_solver.dart';

List<List<int?>> _parse(List<String> rows) =>
    rows
        .map((r) =>
            r.split('').map((c) => c == '.' ? null : int.parse(c)).toList())
        .toList();

void main() {
  group('LogicalSolver.nextStep', () {
    test('finds a naked single', () {
      // All cells of the first row are filled except (0,8) which must be 9.
      final grid = _parse([
        '12345678.',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
      ]);
      final result =
          LogicalSolver.nextStep(grid, SudokuVariant.classic, null);
      expect(result, isNotNull);
      expect(result!.row, 0);
      expect(result.col, 8);
      expect(result.value, 9);
    });

    test('returns a result for a well-known easy puzzle', () {
      final grid = _parse([
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
      final result =
          LogicalSolver.nextStep(grid, SudokuVariant.classic, null);
      expect(result, isNotNull);
    });

    test('returns null for a complete grid', () {
      final grid = _parse([
        '534678912',
        '672195348',
        '198342567',
        '859761423',
        '426853791',
        '713924856',
        '961537284',
        '287419635',
        '345286179',
      ]);
      final result =
          LogicalSolver.nextStep(grid, SudokuVariant.classic, null);
      expect(result, isNull);
    });
  });

  group('LogicalSolver.rateDifficulty', () {
    test('rates an easy puzzle as easy', () {
      final grid = _parse([
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
      final d = LogicalSolver.rateDifficulty(grid, SudokuVariant.classic, null);
      // Easy puzzles should not require expert techniques.
      expect(d.index, lessThanOrEqualTo(SudokuDifficulty.medium.index));
    });
  });
}
