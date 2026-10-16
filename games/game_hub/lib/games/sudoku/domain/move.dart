import 'sudoku_pos.dart';

/// Records a single cell change for undo/redo and replay.
class SudokuMove {
  const SudokuMove({
    required this.pos,
    required this.oldValue,
    required this.newValue,
    required this.oldNotes,
    required this.newNotes,
  });

  final SudokuPos pos;
  final int? oldValue;
  final int? newValue;
  final Set<int> oldNotes;
  final Set<int> newNotes;

  Map<String, dynamic> toJson() => {
        'pos': pos.toJson(),
        'oldValue': oldValue,
        'newValue': newValue,
        'oldNotes': oldNotes.toList(),
        'newNotes': newNotes.toList(),
      };

  factory SudokuMove.fromJson(Map json) => SudokuMove(
        pos: SudokuPos.fromJson(json['pos'] as Map),
        oldValue: json['oldValue'] as int?,
        newValue: json['newValue'] as int?,
        oldNotes: Set<int>.from((json['oldNotes'] as List).cast<int>()),
        newNotes: Set<int>.from((json['newNotes'] as List).cast<int>()),
      );
}
