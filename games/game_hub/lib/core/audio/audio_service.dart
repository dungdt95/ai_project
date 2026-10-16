import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._() {
    // Suppress async platform errors that escape try/catch via the event stream.
    _player.eventStream.listen(null, onError: (_, __) {}, cancelOnError: false);
  }
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;

  Future<void> playMove() => _play('audio/move.mp3');
  Future<void> playWin() => _play('audio/win.mp3');
  Future<void> playLose() => _play('audio/lose.mp3');
  Future<void> playDraw() => _play('audio/draw.mp3');

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }
}
