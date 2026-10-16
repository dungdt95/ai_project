/// A single Sudoku cell. Immutable; isError is computed by the rules layer.
class Cell {
  const Cell({this.value, this.notes = const {}, this.isGiven = false});

  final int? value;
  final Set<int> notes;
  final bool isGiven;

  Cell copyWith({
    int? value,
    bool clearValue = false,
    Set<int>? notes,
    bool? isGiven,
  }) =>
      Cell(
        value: clearValue ? null : (value ?? this.value),
        notes: notes ?? this.notes,
        isGiven: isGiven ?? this.isGiven,
      );

  bool get isEmpty => value == null && notes.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is Cell &&
      other.value == value &&
      other.isGiven == isGiven &&
      _setEq(other.notes, notes);

  @override
  int get hashCode => Object.hash(value, isGiven, Object.hashAll(notes));

  static bool _setEq(Set<int> a, Set<int> b) =>
      a.length == b.length && a.every(b.contains);
}
