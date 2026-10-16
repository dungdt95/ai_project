import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/domain/cell.dart';
import 'package:game_hub/games/sudoku/domain/killer_cage.dart';
import 'package:game_hub/games/sudoku/domain/rules.dart';
import 'package:game_hub/games/sudoku/domain/sudoku_board.dart';
import 'package:game_hub/games/sudoku/domain/sudoku_pos.dart';
import 'package:game_hub/games/sudoku/domain/variant.dart';

SudokuBoard _emptyBoard({
  SudokuVariant variant = SudokuVariant.classic,
  List<KillerCage>? cages,
}) {
  final cells = List.generate(9, (_) => List.generate(9, (_) => const Cell()));
  final solution = List.generate(9, (r) => List.generate(9, (c) => (r * 3 + r ~/ 3 + c) % 9 + 1));
  return SudokuBoard(
    cells: cells,
    solution: solution,
    variant: variant,
    difficulty: SudokuDifficulty.easy,
    cages: cages,
  );
}

SudokuBoard _setCell(SudokuBoard board, int row, int col, int value) =>
    board.withCell(row, col, Cell(value: value));

void main() {
  group('Classic rules', () {
    test('isLegalGrid — row conflict detected', () {
      var board = _emptyBoard();
      board = _setCell(board, 0, 0, 5);
      // Placing 5 elsewhere in same row should be illegal.
      expect(SudokuRules.isLegal(board, 0, 3, 5), isFalse);
      expect(SudokuRules.isLegal(board, 0, 3, 3), isTrue);
    });

    test('isLegalGrid — col conflict detected', () {
      var board = _emptyBoard();
      board = _setCell(board, 2, 4, 7);
      expect(SudokuRules.isLegal(board, 6, 4, 7), isFalse);
      expect(SudokuRules.isLegal(board, 6, 4, 2), isTrue);
    });

    test('isLegalGrid — box conflict detected', () {
      var board = _emptyBoard();
      board = _setCell(board, 0, 0, 4);
      expect(SudokuRules.isLegal(board, 2, 2, 4), isFalse);
      expect(SudokuRules.isLegal(board, 2, 2, 9), isTrue);
    });

    test('conflictingCells returns correct set', () {
      var board = _emptyBoard();
      board = _setCell(board, 0, 0, 3);
      board = _setCell(board, 0, 5, 3); // same row
      board = _setCell(board, 7, 0, 3); // same col
      board = _setCell(board, 2, 2, 3); // same box

      final conflicts = SudokuRules.conflictingCells(board, 0, 0);
      expect(conflicts, contains(SudokuPos(0, 5)));
      expect(conflicts, contains(SudokuPos(7, 0)));
      expect(conflicts, contains(SudokuPos(2, 2)));
    });

    test('peersOf includes row, col, box peers', () {
      final peers = SudokuRules.peersOf(0, 0, SudokuVariant.classic, null);
      // Row
      expect(peers, contains(SudokuPos(0, 8)));
      // Col
      expect(peers, contains(SudokuPos(8, 0)));
      // Box
      expect(peers, contains(SudokuPos(2, 2)));
      // Not self
      expect(peers, isNot(contains(SudokuPos(0, 0))));
    });
  });

  group('X-Sudoku rules', () {
    test('main diagonal conflict detected', () {
      var board = _emptyBoard(variant: SudokuVariant.xSudoku);
      board = _setCell(board, 0, 0, 9);
      // Another cell on the main diagonal should not be 9.
      expect(SudokuRules.isLegal(board, 5, 5, 9), isFalse);
      expect(SudokuRules.isLegal(board, 5, 5, 1), isTrue);
    });

    test('anti-diagonal conflict detected', () {
      var board = _emptyBoard(variant: SudokuVariant.xSudoku);
      board = _setCell(board, 0, 8, 6);
      expect(SudokuRules.isLegal(board, 4, 4, 6), isFalse);
    });

    test('isOnDiagonal', () {
      expect(SudokuRules.isOnDiagonal(0, 0), isTrue);
      expect(SudokuRules.isOnDiagonal(4, 4), isTrue);
      expect(SudokuRules.isOnDiagonal(0, 8), isTrue);
      expect(SudokuRules.isOnDiagonal(8, 0), isTrue);
      expect(SudokuRules.isOnDiagonal(0, 1), isFalse);
    });
  });

  group('Killer rules', () {
    test('cage no-repeat rule', () {
      final cage = KillerCage(
        cells: [SudokuPos(0, 0), SudokuPos(0, 1), SudokuPos(0, 2)],
        sum: 15,
      );
      var board = _emptyBoard(variant: SudokuVariant.killer, cages: [cage]);
      board = _setCell(board, 0, 0, 4);
      expect(SudokuRules.isLegal(board, 0, 1, 4), isFalse);
      expect(SudokuRules.isLegal(board, 0, 1, 5), isTrue);
    });
  });

  group('candidatesFor', () {
    test('all 9 candidates in empty board', () {
      final board = _emptyBoard();
      final grid = board.toGrid();
      final cands = SudokuRules.candidatesFor(grid, 0, 0, SudokuVariant.classic, null);
      expect(cands, hasLength(9));
    });

    test('placed value removed from same row', () {
      var board = _emptyBoard();
      board = _setCell(board, 0, 4, 7);
      final grid = board.toGrid();
      final cands = SudokuRules.candidatesFor(grid, 0, 0, SudokuVariant.classic, null);
      expect(cands, isNot(contains(7)));
    });
  });
}
