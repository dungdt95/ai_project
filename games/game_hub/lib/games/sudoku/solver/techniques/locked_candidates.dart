import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';
import 'technique.dart';

/// Locked Candidates: if all positions for a value inside a box lie in one
/// row/column, eliminate that value from the rest of that row/column.
/// After elimination, a Naked/Hidden Single may appear.
/// Returns a result if an elimination was applied that directly enables a naked single.
class LockedCandidates extends SolvingTechnique {
  @override
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    bool changed = false;

    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        for (int v = 1; v <= 9; v++) {
          // Find box cells where v is a candidate
          final pos = <(int, int)>[];
          for (int r = br * 3; r < br * 3 + 3; r++) {
            for (int c = bc * 3; c < bc * 3 + 3; c++) {
              if (candidates[r][c].contains(v)) pos.add((r, c));
            }
          }
          if (pos.isEmpty || pos.length > 3) continue;

          // All in same row?
          if (pos.every((p) => p.$1 == pos.first.$1)) {
            final row = pos.first.$1;
            for (int c = 0; c < 9; c++) {
              if (c ~/ 3 != bc && candidates[row][c].remove(v)) changed = true;
            }
          }
          // All in same col?
          if (pos.every((p) => p.$2 == pos.first.$2)) {
            final col = pos.first.$2;
            for (int r = 0; r < 9; r++) {
              if (r ~/ 3 != br && candidates[r][col].remove(v)) changed = true;
            }
          }
        }
      }
    }

    // If we eliminated something, check for a naked single that now appears.
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
              description:
                  'Locked Candidates → ô ($r,$c) chỉ còn $value',
              difficulty: SudokuDifficulty.medium,
            );
          }
        }
      }
    }
    return null;
  }
}
