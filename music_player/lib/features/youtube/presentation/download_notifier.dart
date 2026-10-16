import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/audio/player_provider.dart';
import '../data/youtube_repo.dart' show YoutubeRepo, friendlyYoutubeErrorMessage;
import '../domain/download_task.dart';

// Map videoId → DownloadTask
class DownloadNotifier extends StateNotifier<Map<String, DownloadTask>> {
  DownloadNotifier(this._ref) : super({});

  final Ref _ref;
  final _repo = YoutubeRepo();
  final _cancelTokens = <String, CancelToken>{};

  Future<void> startDownload(Video video) async {
    final id = video.id.value;
    if (state.containsKey(id) && state[id]!.isActive) return;

    final task = DownloadTask(
      videoId: id,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      durationSeconds: video.duration?.inSeconds,
      status: DownloadStatus.downloading,
    );

    state = {...state, id: task};
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      final song = await _repo.downloadAudio(
        video,
        cancelToken: cancelToken,
        onProgress: (p) {
          final current = state[id];
          if (current != null) {
            state = {...state, id: current.copyWith(progress: p)};
          }
        },
      );

      // Add to library
      _ref.read(libraryProvider.notifier).addSongs([song]);

      state = {
        ...state,
        id: task.copyWith(
          status: DownloadStatus.done,
          progress: 1.0,
          filePath: song.filePath,
        ),
      };
    } catch (e) {
      state = {
        ...state,
        id: task.copyWith(status: DownloadStatus.error, errorMsg: friendlyYoutubeErrorMessage(e)),
      };
    } finally {
      _cancelTokens.remove(id);
    }
  }

  void cancel(String videoId) {
    _cancelTokens[videoId]?.cancel();
  }

  void remove(String videoId) {
    final map = Map<String, DownloadTask>.from(state);
    map.remove(videoId);
    state = map;
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadTask>>(
  (ref) => DownloadNotifier(ref),
);
