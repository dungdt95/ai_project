import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';
import 'technique.dart';

/// X-Wing: a value appears as a candidate in exactly two cells in two different
/// rows, and those cells share the same two columns.  Eliminate the value from
/// all other cells in those columns.
class XWing extends SolvingTechnique {
  @override
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    bool changed = false;

    for (int v = 1; v <= 9; v++) {
      // Collect rows where v appears in exactly 2 columns
      final rowPairs = <int, List<int>>{};
      for (int r = 0; r < 9; r++) {
        final cols = [
          for (int c = 0; c < 9; c++)
            if (candidates[r][c].contains(v)) c,
        ];
        if (cols.length == 2) rowPairs[r] = cols;
      }

      final rowList = rowPairs.keys.toList();
      for (int i = 0; i < rowList.length; i++) {
        for (int j = i + 1; j < rowList.length; j++) {
          final r1 = rowList[i], r2 = rowList[j];
          if (rowPairs[r1]![0] != rowPairs[r2]![0]) continue;
          if (rowPairs[r1]![1] != rowPairs[r2]![1]) continue;

          final c1 = rowPairs[r1]![0], c2 = rowPairs[r1]![1];
          for (int r = 0; r < 9; r++) {
            if (r == r1 || r == r2) continue;
            if (candidates[r][c1].remove(v)) changed = true;
            if (candidates[r][c2].remove(v)) changed = true;
          }
        }
      }
    }

    if (changed) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (grid[r][c] != null) continue;
          if (candidates[r][c].length == 1) {
            final value = candidates[r][c].first;
            return TechniqueResult(
              row: r,
              col: c,
              value: value,
              description: 'X-Wing → ô ($r,$c) chỉ còn $value',
              difficulty: SudokuDifficulty.expert,
            );
          }
        }
      }
    }
    return null;
  }
}
