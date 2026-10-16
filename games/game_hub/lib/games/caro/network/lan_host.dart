import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'protocol.dart';

enum HostState { waiting, connected, playing, ended }

/// Manages the TCP server side of a LAN game.
class LanHost {
  LanHost({required this.hostName, required this.boardSize});

  final String hostName;
  final int boardSize;

  ServerSocket? _server;
  Socket? _client;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  HostState state = HostState.waiting;
  String? clientName;
  int port = 0;

  final _packets = StreamController<Packet>.broadcast();
  Stream<Packet> get onPacket => _packets.stream;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get onError => _errors.stream;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    port = _server!.port;
    _server!.first.then(_handleClient);
  }

  void _handleClient(Socket socket) {
    state = HostState.connected;
    _client = socket;

    // Send welcome message after client says hello.
    final buf = StringBuffer();
    _sub = socket.listen(
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
          if (p.type == PacketType.hello) {
            clientName = p.payload['name'] as String? ?? 'Opponent';
            _send(Packet.welcome(
              side: 'O', // host is X, client is O
              hostName: hostName,
              boardSize: boardSize,
            ));
            state = HostState.playing;
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
      _client?.write(p.encode());
    } catch (_) {}
  }

  void _onDisconnect() {
    state = HostState.ended;
    _errors.add('disconnected');
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    _sub?.cancel();
    await _client?.close();
    await _server?.close();
    await _packets.close();
    await _errors.close();
  }
}
