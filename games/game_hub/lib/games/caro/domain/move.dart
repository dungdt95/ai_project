/// A single board coordinate.
class Position {
  const Position(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';

  Map<String, int> toJson() => {'r': row, 'c': col};

  factory Position.fromJson(Map<dynamic, dynamic> j) =>
      Position(j['r'] as int, j['c'] as int);
}

enum Player { x, o }

extension PlayerExt on Player {
  Player get opponent => this == Player.x ? Player.o : Player.x;
  String get label => this == Player.x ? 'X' : 'O';
}

/// One stone placed on the board.
class Move {
  const Move({
    required this.position,
    required this.player,
    required this.timestamp,
  });

  final Position position;
  final Player player;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'r': position.row,
        'c': position.col,
        'p': player.index,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory Move.fromJson(Map<dynamic, dynamic> j) => Move(
        position: Position(j['r'] as int, j['c'] as int),
        player: Player.values[j['p'] as int],
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
}
