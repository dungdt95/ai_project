import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'protocol.dart';

enum ClientState { connecting, connected, playing, ended }

/// Manages the TCP client side of a LAN game.
class LanClient {
  LanClient({required this.playerName});

  final String playerName;

  Socket? _socket;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  ClientState state = ClientState.connecting;
  String? hostName;
  int boardSize = 15;

  final _packets = StreamController<Packet>.broadcast();
  Stream<Packet> get onPacket => _packets.stream;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get onError => _errors.stream;

  Future<void> connect(String ip, int port) async {
    _socket = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 10));
    state = ClientState.connected;

    // Identify ourselves.
    _socket!.write(Packet.hello(name: playerName).encode());

    final buf = StringBuffer();
    _sub = _socket!.listen(
      (bytes) {
        final chunk = utf8.decode(bytes, allowMalformed: true);
        buf.write(chunk);
        final lines = buf.toString().split('\n');
        buf.clear();
        if (lines.length > 1) buf.write(lines.last);
        for (final line in lines.sublist(0, lines.length - 1)) {
          if (line.trim().isEmpty) continue;
          final p = Packet.decode(line);
          if (p == null) continue;
          if (p.type == PacketType.welcome) {
            hostName = p.payload['hostName'] as String? ?? 'Host';
            boardSize = p.payload['boardSize'] as int? ?? 15;
            state = ClientState.playing;
          } else if (p.type == PacketType.ping) {
            _send(Packet.pong);
          } else {
            _packets.add(p);
          }
        }
      },
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
    );

    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _send(Packet.ping));
  }

  void sendMove({required int row, required int col, required int moveNo}) =>
      _send(Packet.move(row: row, col: col, moveNo: moveNo));

  void sendEnd({required String result, List<List<int>>? winningLine}) =>
      _send(Packet.end(result: result, winningLine: winningLine));

  void sendRematchRequest() => _send(Packet.rematchRequest);
  void sendRematchAccept() => _send(Packet.rematchAccept);
  void sendRematchDecline() => _send(Packet.rematchDecline);

  void _send(Packet p) {
    try {
      _socket?.write(p.encode());
    } catch (_) {}
  }

  void _onDisconnect() {
    state = ClientState.ended;
    _errors.add('disconnected');
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    _sub?.cancel();
    await _socket?.close();
    await _packets.close();
    await _errors.close();
  }
}
