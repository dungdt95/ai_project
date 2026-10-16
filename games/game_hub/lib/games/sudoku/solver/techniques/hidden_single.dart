import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';
import 'technique.dart';

/// A value that can only go in one cell within a row, column, or 3×3 box.
class HiddenSingle extends SolvingTechnique {
  @override
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    // Check rows
    for (int r = 0; r < 9; r++) {
      final result = _checkUnit(
        candidates,
        [for (int c = 0; c < 9; c++) (r, c)],
        'hàng ${r + 1}',
      );
      if (result != null) return result;
    }
    // Check cols
    for (int c = 0; c < 9; c++) {
      final result = _checkUnit(
        candidates,
        [for (int r = 0; r < 9; r++) (r, c)],
        'cột ${c + 1}',
      );
      if (result != null) return result;
    }
    // Check boxes
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        final cells = [
          for (int r = br * 3; r < br * 3 + 3; r++)
            for (int c = bc * 3; c < bc * 3 + 3; c++) (r, c),
        ];
        final result =
            _checkUnit(candidates, cells, 'box (${br + 1},${bc + 1})');
        if (result != null) return result;
      }
    }
    // X-Sudoku diagonals
    if (variant == SudokuVariant.xSudoku) {
      final main = [for (int i = 0; i < 9; i++) (i, i)];
      final anti = [for (int i = 0; i < 9; i++) (i, 8 - i)];
      return _checkUnit(candidates, main, 'đường chéo chính') ??
          _checkUnit(candidates, anti, 'đường chéo phụ');
    }
    return null;
  }

  static TechniqueResult? _checkUnit(
    List<List<Set<int>>> candidates,
    List<(int, int)> cells,
    String unitName,
  ) {
    for (int v = 1; v <= 9; v++) {
      final possible =
          cells.where((p) => candidates[p.$1][p.$2].contains(v)).toList();
      if (possible.length == 1) {
        final (r, c) = possible.first;
        return TechniqueResult(
          row: r,
          col: c,
          value: v,
          description: 'Hidden Single: $v chỉ có thể ở ô ($r,$c) trong $unitName',
          difficulty: SudokuDifficulty.easy,
        );
      }
    }
    return null;
  }
}
