import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/library/domain/playlist.dart';
import '../../features/library/domain/song.dart';
import '../../core/database/hive_boxes.dart';
import 'audio_handler.dart';

final audioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

// ── Library ───────────────────────────────────────────────────────────────────

enum SortMode { title, artist, recentlyAdded }

class LibraryNotifier extends StateNotifier<List<Song>> {
  LibraryNotifier() : super([]);

  SortMode _sort = SortMode.title;
  SortMode get sortMode => _sort;

  void setSongs(List<Song> songs) => state = _sorted(songs);
  void addSongs(List<Song> songs) => state = _sorted([...state, ...songs]);
  void removeSong(String id) => state = state.where((s) => s.id != id).toList();

  void setSort(SortMode mode) {
    _sort = mode;
    state = _sorted(state);
  }

  List<Song> _sorted(List<Song> songs) {
    final list = [...songs];
    switch (_sort) {
      case SortMode.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortMode.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
      case SortMode.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return list;
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, List<Song>>(
  (_) => LibraryNotifier(),
);

// ── Playlists ─────────────────────────────────────────────────────────────────

class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  PlaylistNotifier() : super(HiveBoxes.playlists.values.toList());

  final _uuid = const Uuid();

  Future<Playlist> create(String name) async {
    final p = Playlist(
      id: _uuid.v4(),
      name: name,
      songIds: [],
      createdAt: DateTime.now(),
    );
    await HiveBoxes.playlists.put(p.id, p);
    state = [...state, p];
    return p;
  }

  Future<void> addSong(String playlistId, String songId) async {
    final p = HiveBoxes.playlists.get(playlistId);
    if (p == null || p.songIds.contains(songId)) return;
    p.songIds = [...p.songIds, songId];
    await p.save();
    state = [...state];
  }

  Future<void> removeSong(String playlistId, String songId) async {
    final p = HiveBoxes.playlists.get(playlistId);
    if (p == null) return;
    p.songIds = p.songIds.where((id) => id != songId).toList();
    await p.save();
    state = [...state];
  }

  Future<void> delete(String playlistId) async {
    await HiveBoxes.playlists.delete(playlistId);
    state = state.where((p) => p.id != playlistId).toList();
  }

  Future<void> rename(String playlistId, String newName) async {
    final p = HiveBoxes.playlists.get(playlistId);
    if (p == null) return;
    p.name = newName;
    await p.save();
    state = [...state];
  }

  List<Song> getSongs(String playlistId, List<Song> allSongs) {
    final p = HiveBoxes.playlists.get(playlistId);
    if (p == null) return [];
    final map = {for (final s in allSongs) s.id: s};
    return p.songIds.map((id) => map[id]).whereType<Song>().toList();
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, List<Playlist>>(
  (_) => PlaylistNotifier(),
);

// ── Player ────────────────────────────────────────────────────────────────────

class PlayerState {
  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = AudioServiceRepeatMode.none,
  });

  final Song? currentSong;
  final List<Song> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final AudioServiceRepeatMode repeatMode;

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    AudioServiceRepeatMode? repeatMode,
  }) => PlayerState(
    currentSong: currentSong ?? this.currentSong,
    queue: queue ?? this.queue,
    currentIndex: currentIndex ?? this.currentIndex,
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
  );
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier(this._handler) : super(const PlayerState()) {
    _handler.playbackState.listen(_onPlaybackState);
    _handler.mediaItem.listen(_onMediaItem);
    _handler.positionStream.listen((pos) => state = state.copyWith(position: pos));
    _handler.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
  }

  final MusicAudioHandler _handler;

  void _onPlaybackState(PlaybackState s) {
    state = state.copyWith(
      isPlaying: s.playing,
      shuffle: s.shuffleMode == AudioServiceShuffleMode.all,
      repeatMode: s.repeatMode,
    );
  }

  void _onMediaItem(MediaItem? item) {
    if (item == null) return;
    final idx = _handler.currentIndex ?? 0;
    if (idx < state.queue.length) {
      state = state.copyWith(currentIndex: idx, currentSong: state.queue[idx]);
    }
  }

  Future<void> playSong(List<Song> queue, int index) async {
    state = state.copyWith(queue: queue, currentIndex: index, currentSong: queue[index]);
    await _handler.setQueueFromSongs(queue, index);
    await _handler.play();
  }

  Future<void> togglePlay() async =>
      state.isPlaying ? await _handler.pause() : await _handler.play();

  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration pos) => _handler.seek(pos);
  Future<void> skipToIndex(int index) => _handler.skipToQueueItem(index);

  Future<void> toggleShuffle() =>
      _handler.setShuffleMode(state.shuffle
          ? AudioServiceShuffleMode.none
          : AudioServiceShuffleMode.all);

  Future<void> cycleRepeat() {
    final next = switch (state.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all  => AudioServiceRepeatMode.one,
      _                           => AudioServiceRepeatMode.none,
    };
    return _handler.setRepeatMode(next);
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref.read(audioHandlerProvider));
});
