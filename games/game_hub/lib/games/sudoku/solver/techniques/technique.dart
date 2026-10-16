import '../../domain/killer_cage.dart';
import '../../domain/variant.dart';

class TechniqueResult {
  const TechniqueResult({
    required this.row,
    required this.col,
    required this.value,
    required this.description,
    this.difficulty = SudokuDifficulty.easy,
  });

  final int row, col, value;
  final String description;
  final SudokuDifficulty difficulty;
}

abstract class SolvingTechnique {
  TechniqueResult? apply(
    List<List<int?>> grid,
    List<List<Set<int>>> candidates,
    SudokuVariant variant,
    List<KillerCage>? cages,
  );
}
