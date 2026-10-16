import 'move.dart';

enum GameStatus { playing, xWon, oWon, draw }

/// Immutable board state.
class Board {
  Board({int size = 15})
      : size = size,
        cells = List.generate(size, (_) => List.filled(size, null)),
        history = const [],
        winningLine = null,
        status = GameStatus.playing;

  Board._({
    required this.size,
    required this.cells,
    required this.history,
    required this.status,
    required this.winningLine,
  });

  final int size;
  final List<List<Player?>> cells;
  final List<Move> history;
  final GameStatus status;
  final List<Position>? winningLine;

  Player get currentTurn =>
      history.length % 2 == 0 ? Player.x : Player.o;

  bool get isOver => status != GameStatus.playing;

  Player? at(int row, int col) => cells[row][col];
  bool isEmpty(int row, int col) => cells[row][col] == null;

  bool isInBounds(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  /// Returns a new Board with the move applied (does not validate legality).
  Board applyMove(Move move) {
    final newCells = [
      for (final row in cells) List<Player?>.from(row),
    ];
    newCells[move.position.row][move.position.col] = move.player;
    final newHistory = [...history, move];
    return Board._(
      size: size,
      cells: newCells,
      history: newHistory,
      status: GameStatus.playing,
      winningLine: null,
    );
  }

  Board withStatus(GameStatus s, {List<Position>? line}) => Board._(
        size: size,
        cells: cells,
        history: history,
        status: s,
        winningLine: line ?? winningLine,
      );

  /// Returns a copy with the last [count] moves removed.
  Board undoMoves(int count) {
    assert(history.length >= count);
    final newHistory = history.sublist(0, history.length - count);
    final newCells = List.generate(size, (_) => List<Player?>.filled(size, null));
    for (final m in newHistory) {
      newCells[m.position.row][m.position.col] = m.player;
    }
    return Board._(
      size: size,
      cells: newCells,
      history: newHistory,
      status: GameStatus.playing,
      winningLine: null,
    );
  }

  /// Serialize board cells as flat int list for Isolate passing.
  List<int> toCellList() {
    final list = <int>[];
    for (final row in cells) {
      for (final cell in row) {
        list.add(cell == null ? 0 : (cell == Player.x ? 1 : 2));
      }
    }
    return list;
  }

  factory Board.fromCellList(List<int> flat, int size) {
    final cells = List.generate(
      size,
      (r) => List<Player?>.generate(size, (c) {
        final v = flat[r * size + c];
        return v == 0 ? null : (v == 1 ? Player.x : Player.o);
      }),
    );
    return Board._(
      size: size,
      cells: cells,
      history: const [],
      status: GameStatus.playing,
      winningLine: null,
    );
  }
}
