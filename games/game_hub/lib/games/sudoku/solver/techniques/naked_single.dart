import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';
import 'technique.dart';

/// A cell with exactly one candidate — the value must go there.
class NakedSingle extends SolvingTechnique {
  @override
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] != null) continue;
        if (candidates[r][c].length == 1) {
          final v = candidates[r][c].first;
          return TechniqueResult(
            row: r,
            col: c,
            value: v,
            description: 'Naked Single: ô ($r,$c) chỉ có thể là $v',
            difficulty: SudokuDifficulty.easy,
          );
        }
      }
    }
    return null;
  }
}
