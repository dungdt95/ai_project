/// A position on the 9×9 Sudoku grid.
class SudokuPos {
  const SudokuPos(this.row, this.col);
  final int row, col;

  @override
  bool operator ==(Object other) =>
      other is SudokuPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory SudokuPos.fromJson(Map json) =>
      SudokuPos(json['row'] as int, json['col'] as int);
}
