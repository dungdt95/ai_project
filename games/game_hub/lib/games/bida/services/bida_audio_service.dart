import 'package:audioplayers/audioplayers.dart';
import '../domain/shot_result.dart';

class BidaAudioService {
  final AudioPlayer _hitPlayer = AudioPlayer();
  final AudioPlayer _cushionPlayer = AudioPlayer();
  final AudioPlayer _pocketPlayer = AudioPlayer();

  static const _prefix = 'bida/audio/';

  Future<void> playForResult(ShotResult result) async {
    if (result.pocketedIds.isNotEmpty) {
      await playPocket();
    } else if (result.cushionHits.isNotEmpty) {
      await playCushionHit();
    } else if (result.firstBallHitId != null) {
      await playBallHit();
    }
  }

  Future<void> playBallHit({double volume = 0.8}) =>
      _play(_hitPlayer, 'ball_hit.mp3', volume: volume);

  Future<void> playCushionHit({double volume = 0.6}) =>
      _play(_cushionPlayer, 'cushion_hit.mp3', volume: volume);

  Future<void> playPocket({double volume = 1.0}) =>
      _play(_pocketPlayer, 'pocket.mp3', volume: volume);

  Future<void> _play(AudioPlayer player, String filename, {double volume = 1.0}) async {
    try {
      // Suppress async platform errors from audioplayers (e.g. missing asset file)
      player.onPlayerStateChanged.first.catchError((_) => PlayerState.stopped);
      await player.play(AssetSource('$_prefix$filename'), volume: volume);
    } catch (_) {
      // Missing audio file or platform error — silent fallback
    }
  }

  void dispose() {
    _hitPlayer.dispose();
    _cushionPlayer.dispose();
    _pocketPlayer.dispose();
  }
}
