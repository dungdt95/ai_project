import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/library/domain/song.dart';

class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  MusicAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  // ── Queue management ─────────────────────────────────────────────────────────

  Future<void> setQueueFromSongs(List<Song> songs, int startIndex) async {
    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);
    mediaItem.add(items[startIndex]);

    final sources = songs.map((s) => AudioSource.uri(Uri.file(s.filePath))).toList();
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: startIndex,
    );
  }

  // ── Controls ─────────────────────────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      final idx = _player.currentIndex ?? 0;
      final q = queue.value;
      if (idx < q.length) mediaItem.add(q[idx]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If > 3s in — restart; else go to previous
    if ((_player.position.inSeconds) > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
      final idx = _player.currentIndex ?? 0;
      final q = queue.value;
      if (idx < q.length) mediaItem.add(q[idx]);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    final q = queue.value;
    if (index < q.length) mediaItem.add(q[index]);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one  => LoopMode.one,
      AudioServiceRepeatMode.all  => LoopMode.all,
      _                           => LoopMode.off,
    };
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  // ── Streams ───────────────────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get playing => _player.playing;
  Duration get position => _player.position;
  int? get currentIndex => _player.currentIndex;

  void _broadcastState(PlaybackEvent event) {
    final isPlaying = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle      => AudioProcessingState.idle,
        ProcessingState.loading   => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready     => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: isPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  static MediaItem _songToMediaItem(Song s) => MediaItem(
        id: s.filePath,
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: Duration(milliseconds: s.durationMs),
        artUri: s.artworkPath != null ? Uri.file(s.artworkPath!) : null,
      );
}
