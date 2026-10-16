import 'dart:convert';

/// Packet types exchanged between host and client over TCP.
enum PacketType {
  hello,
  welcome,
  move,
  end,
  ping,
  pong,
  rematchRequest,
  rematchAccept,
  rematchDecline,
}

/// JSON-serializable packet sent over the TCP connection.
class Packet {
  const Packet(this.type, [this.payload = const {}]);

  final PacketType type;
  final Map<String, dynamic> payload;

  String encode() => '${jsonEncode({'t': type.name, ...payload})}\n';

  static Packet? decode(String raw) {
    try {
      final map = jsonDecode(raw.trim()) as Map<String, dynamic>;
      final t = PacketType.values.firstWhere(
        (e) => e.name == map['t'],
        orElse: () => PacketType.ping,
      );
      final payload = Map<String, dynamic>.from(map)..remove('t');
      return Packet(t, payload);
    } catch (_) {
      return null;
    }
  }

  // ── Convenience factories ──────────────────────────────────────────

  factory Packet.hello({required String name}) =>
      Packet(PacketType.hello, {'name': name, 'version': 1});

  factory Packet.welcome({
    required String side,
    required String hostName,
    required int boardSize,
  }) =>
      Packet(PacketType.welcome, {
        'side': side,
        'hostName': hostName,
        'boardSize': boardSize,
      });

  factory Packet.move({required int row, required int col, required int moveNo}) =>
      Packet(PacketType.move, {
        'row': row,
        'col': col,
        'no': moveNo,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

  factory Packet.end({
    required String result,
    List<List<int>>? winningLine,
  }) =>
      Packet(PacketType.end, {
        'result': result,
        if (winningLine != null) 'line': winningLine,
      });

  static const ping = Packet(PacketType.ping);
  static const pong = Packet(PacketType.pong);
  static const rematchRequest = Packet(PacketType.rematchRequest);
  static const rematchAccept = Packet(PacketType.rematchAccept);
  static const rematchDecline = Packet(PacketType.rematchDecline);
}
