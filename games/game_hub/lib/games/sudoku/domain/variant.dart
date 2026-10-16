enum SudokuVariant {
  classic,
  killer,
  xSudoku;

  String get label => switch (this) {
        SudokuVariant.classic => 'Classic',
        SudokuVariant.killer => 'Killer',
        SudokuVariant.xSudoku => 'X-Sudoku',
      };

  String get description => switch (this) {
        SudokuVariant.classic => 'Luật chuẩn 9×9',
        SudokuVariant.killer => 'Tổng cage bằng số cho trước',
        SudokuVariant.xSudoku => 'Thêm ràng buộc 2 đường chéo',
      };
}

enum SudokuDifficulty {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
        SudokuDifficulty.easy => 'Dễ',
        SudokuDifficulty.medium => 'Trung bình',
        SudokuDifficulty.hard => 'Khó',
        SudokuDifficulty.expert => 'Expert',
      };

  /// Target number of given cells in the puzzle.
  int get givenTarget => switch (this) {
        SudokuDifficulty.easy => 40,
        SudokuDifficulty.medium => 32,
        SudokuDifficulty.hard => 28,
        SudokuDifficulty.expert => 24,
      };
}
