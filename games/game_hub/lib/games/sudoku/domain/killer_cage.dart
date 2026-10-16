import 'sudoku_pos.dart';

/// A Killer Sudoku cage: a group of adjacent cells whose values must sum to [sum]
/// and contain no repeated digits.
class KillerCage {
  const KillerCage({required this.cells, required this.sum});
  final List<SudokuPos> cells;
  final int sum;

  Map<String, dynamic> toJson() => {
        'cells': cells.map((p) => p.toJson()).toList(),
        'sum': sum,
      };

  factory KillerCage.fromJson(Map json) => KillerCage(
        cells:
            (json['cells'] as List).map((e) => SudokuPos.fromJson(e as Map)).toList(),
        sum: json['sum'] as int,
      );
}
