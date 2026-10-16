import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/domain/cell.dart';
import 'package:game_hub/games/sudoku/domain/killer_cage.dart';
import 'package:game_hub/games/sudoku/domain/rules.dart';
import 'package:game_hub/games/sudoku/domain/sudoku_board.dart';
import 'package:game_hub/games/sudoku/domain/sudoku_pos.dart';
import 'package:game_hub/games/sudoku/domain/variant.dart';

SudokuBoard _board(List<KillerCage> cages) {
  final cells = List.generate(9, (_) => List.generate(9, (_) => const Cell()));
  final solution = List.generate(9, (r) => List.generate(9, (c) => (r + c) % 9 + 1));
  return SudokuBoard(
    cells: cells,
    solution: solution,
    variant: SudokuVariant.killer,
    difficulty: SudokuDifficulty.easy,
    cages: cages,
  );
}

SudokuBoard _setCell(SudokuBoard board, int row, int col, int value) =>
    board.withCell(row, col, Cell(value: value));

void main() {
  group('Killer cage sum constraint', () {
    final cage = KillerCage(
      cells: [SudokuPos(0, 0), SudokuPos(0, 1)],
      sum: 9,
    );

    test('placing a value that makes partial sum feasible is legal', () {
      final board = _board([cage]);
      // 4 + 5 = 9, so placing 4 first should be legal.
      expect(SudokuRules.isLegal(board, 0, 0, 4), isTrue);
    });

    test('placing a value that makes sum impossible is illegal', () {
      var board = _board([cage]);
      board = _setCell(board, 0, 0, 8);
      // The remaining cell must be 1 to sum to 9, but we check if 8 can fit:
      // 8 + anything_1-9 >= 9 only works for 1. Placing 8 again violates no-repeat.
      expect(SudokuRules.isLegal(board, 0, 1, 8), isFalse); // repeat
    });

    test('last cell with wrong sum is illegal', () {
      var board = _board([cage]);
      board = _setCell(board, 0, 0, 3);
      // Remaining cell: 3 + ? = 9, so ? = 6.
      expect(SudokuRules.isLegal(board, 0, 1, 7), isFalse); // 3+7=10 ≠ 9
      expect(SudokuRules.isLegal(board, 0, 1, 6), isTrue);  // 3+6=9 ✓
    });
  });
}
