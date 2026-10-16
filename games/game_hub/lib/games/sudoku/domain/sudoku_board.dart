import 'dart:convert';
import 'cell.dart';
import 'killer_cage.dart';
import 'sudoku_pos.dart';
import 'variant.dart';

/// Immutable 9×9 Sudoku board. Returns new instances on mutation.
class SudokuBoard {
  const SudokuBoard({
    required this.cells,
    required this.solution,
    required this.variant,
    required this.difficulty,
    this.cages,
    this.isDaily = false,
  });

  final List<List<Cell>> cells; // [row][col]
  final List<List<int>> solution; // full correct solution [row][col]
  final SudokuVariant variant;
  final SudokuDifficulty difficulty;
  final List<KillerCage>? cages;
  final bool isDaily;

  Cell cellAt(int row, int col) => cells[row][col];

  SudokuBoard withCell(int row, int col, Cell cell) {
    final next = List.generate(
      9,
      (r) => List.generate(9, (c) => r == row && c == col ? cell : cells[r][c]),
    );
    return SudokuBoard(
      cells: next,
      solution: solution,
      variant: variant,
      difficulty: difficulty,
      cages: cages,
      isDaily: isDaily,
    );
  }

  bool get isComplete => cells.every((row) => row.every((c) => c.value != null));

  bool get isSolved {
    if (!isComplete) return false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (cells[r][c].value != solution[r][c]) return false;
      }
    }
    return true;
  }

  /// Flat int grid for solver operations (null = empty).
  List<List<int?>> toGrid() =>
      List.generate(9, (r) => List.generate(9, (c) => cells[r][c].value));

  /// Count how many cells already display each digit (for number-pad badges).
  Map<int, int> countPlaced() {
    final m = {for (int d = 1; d <= 9; d++) d: 0};
    for (final row in cells) {
      for (final cell in row) {
        if (cell.value != null) m[cell.value!] = m[cell.value!]! + 1;
      }
    }
    return m;
  }

  /// Returns the SudokuPos of every empty (non-given) cell.
  List<SudokuPos> emptyCells() {
    final result = <SudokuPos>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (cells[r][c].value == null) result.add(SudokuPos(r, c));
      }
    }
    return result;
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'cells': List.generate(
          9,
          (r) => List.generate(9, (c) => _cellToJson(cells[r][c])),
        ),
        'solution': solution,
        'variant': variant.index,
        'difficulty': difficulty.index,
        'cages': cages?.map((k) => k.toJson()).toList(),
        'isDaily': isDaily,
      };

  factory SudokuBoard.fromJson(Map<String, dynamic> j) => SudokuBoard(
        cells: (j['cells'] as List)
            .map((row) =>
                (row as List).map((c) => _cellFromJson(c as Map)).toList())
            .toList(),
        solution: (j['solution'] as List)
            .map((row) => (row as List).cast<int>())
            .toList(),
        variant: SudokuVariant.values[j['variant'] as int],
        difficulty: SudokuDifficulty.values[j['difficulty'] as int],
        cages: j['cages'] == null
            ? null
            : (j['cages'] as List)
                .map((e) => KillerCage.fromJson(e as Map))
                .toList(),
        isDaily: j['isDaily'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory SudokuBoard.fromJsonString(String s) =>
      SudokuBoard.fromJson(jsonDecode(s) as Map<String, dynamic>);

  static Map<String, dynamic> _cellToJson(Cell c) => {
        'v': c.value,
        'n': c.notes.toList(),
        'g': c.isGiven,
      };

  static Cell _cellFromJson(Map c) => Cell(
        value: c['v'] as int?,
        notes: Set<int>.from((c['n'] as List).cast<int>()),
        isGiven: c['g'] as bool,
      );
}
