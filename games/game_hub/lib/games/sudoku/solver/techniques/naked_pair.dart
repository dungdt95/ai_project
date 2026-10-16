import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';
import 'technique.dart';

/// Naked Pair: two cells in a unit share the exact same two candidates.
/// Eliminate those two values from other cells in the unit.
class NakedPair extends SolvingTechnique {
  @override
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  ) {
    final units = _buildUnits(variant);
    bool changed = false;

    for (final unit in units) {
      // Find cells with exactly 2 candidates
      final pairs = unit.where((p) => candidates[p.$1][p.$2].length == 2).toList();
      for (int i = 0; i < pairs.length; i++) {
        for (int j = i + 1; j < pairs.length; j++) {
          final a = candidates[pairs[i].$1][pairs[i].$2];
          final b = candidates[pairs[j].$1][pairs[j].$2];
          if (!_setEq(a, b)) continue;

          // Found a naked pair — eliminate from rest of unit
          for (final p in unit) {
            if (p == pairs[i] || p == pairs[j]) continue;
            for (final v in a) {
              if (candidates[p.$1][p.$2].remove(v)) changed = true;
            }
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
              description: 'Naked Pair → ô ($r,$c) chỉ còn $value',
              difficulty: SudokuDifficulty.hard,
            );
          }
        }
      }
    }
    return null;
  }

  static List<List<(int, int)>> _buildUnits(SudokuVariant variant) {
    final units = <List<(int, int)>>[];
    for (int r = 0; r < 9; r++) {
      units.add([for (int c = 0; c < 9; c++) (r, c)]);
    }
    for (int c = 0; c < 9; c++) {
      units.add([for (int r = 0; r < 9; r++) (r, c)]);
    }
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        units.add([
          for (int r = br * 3; r < br * 3 + 3; r++)
            for (int c = bc * 3; c < bc * 3 + 3; c++) (r, c),
        ]);
      }
    }
    if (variant == SudokuVariant.xSudoku) {
      units.add([for (int i = 0; i < 9; i++) (i, i)]);
      units.add([for (int i = 0; i < 9; i++) (i, 8 - i)]);
    }
    return units;
  }

  static bool _setEq(Set<int> a, Set<int> b) =>
      a.length == b.length && a.every(b.contains);
}
