import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/domain/variant.dart';
import 'package:game_hub/games/sudoku/solver/backtrack_solver.dart';
import 'package:game_hub/games/sudoku/solver/generator.dart';

void main() {
  group('Generator', () {
    test('generates a Classic Easy puzzle with unique solution', () {
      final result = generatePuzzle(
        const GeneratorParams(
          variant: 0, // classic
          difficulty: 0, // easy
          seed: 42,
        ),
      );
      expect(result.solution, hasLength(9));
      expect(result.given, hasLength(9));

      // Solution must be complete
      for (final row in result.solution) {
        expect(row, hasLength(9));
        for (final v in row) {
          expect(v, greaterThanOrEqualTo(1));
          expect(v, lessThanOrEqualTo(9));
        }
      }

      // Puzzle should have unique solution
      expect(
        BacktrackSolver.hasUniqueSolution(result.given, SudokuVariant.classic, null),
        isTrue,
      );
    });

    test('generates a Classic Medium puzzle with correct given count', () {
      final result = generatePuzzle(
        const GeneratorParams(
          variant: 0,
          difficulty: 1, // medium
          seed: 123,
        ),
      );
      final givenCount = result.given
          .expand((r) => r)
          .where((v) => v != null)
          .length;
      // Should be close to target (32 for medium) ± 5
      expect(givenCount, greaterThan(25));
      expect(givenCount, lessThan(45));
    });

    test('same seed produces same puzzle', () {
      final p1 = generatePuzzle(const GeneratorParams(variant: 0, difficulty: 0, seed: 999));
      final p2 = generatePuzzle(const GeneratorParams(variant: 0, difficulty: 0, seed: 999));
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          expect(p1.given[r][c], equals(p2.given[r][c]));
        }
      }
    });

    test('different seeds produce different puzzles (usually)', () {
      final p1 = generatePuzzle(const GeneratorParams(variant: 0, difficulty: 0, seed: 1));
      final p2 = generatePuzzle(const GeneratorParams(variant: 0, difficulty: 0, seed: 2));
      // They should differ in at least one cell.
      bool differ = false;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (p1.given[r][c] != p2.given[r][c]) {
            differ = true;
            break;
          }
        }
        if (differ) break;
      }
      expect(differ, isTrue);
    });

    test('Killer variant generates cages covering all 81 cells', () {
      final result = generatePuzzle(
        const GeneratorParams(variant: 1, difficulty: 0, seed: 77),
      );
      expect(result.cages, isNotNull);
      final allCells = result.cages!.expand((c) => c.cells).toSet();
      expect(allCells, hasLength(81));
    });

    test('X-Sudoku variant has no cages', () {
      final result = generatePuzzle(
        const GeneratorParams(variant: 2, difficulty: 0, seed: 55),
      );
      expect(result.cages, isNull);
    });
  });
}
