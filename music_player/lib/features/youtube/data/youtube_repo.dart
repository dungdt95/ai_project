import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/database/hive_boxes.dart';
import '../../library/domain/song.dart';

/// Turns exceptions from `youtube_explode_dart`/`dio`/`dart:io` into a short
/// Vietnamese message fit for display, instead of the raw exception dump.
String friendlyYoutubeErrorMessage(Object error) {
  if (error is RequestLimitExceededException) {
    return 'YouTube đang tạm giới hạn do có quá nhiều yêu cầu từ mạng này. '
        'Vui lòng đợi vài phút rồi thử lại.';
  }
  if (error is VideoUnavailableException) {
    return 'Video không tồn tại, ở chế độ riêng tư, hoặc đã bị gỡ.';
  }
  if (error is VideoUnplayableException) {
    return 'Video này không thể tải (có thể bị giới hạn độ tuổi hoặc chặn khu vực).';
  }
  if (error is YoutubeExplodeException) {
    return 'Không lấy được thông tin từ YouTube. Vui lòng thử lại sau.';
  }
  if (error is SocketException || error is HttpException) {
    return 'Không có kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
  }
  if (error is TimeoutException) {
    return 'Kết nối tới YouTube quá chậm hoặc bị treo. Vui lòng thử lại.';
  }
  if (error is DioException) {
    if (CancelToken.isCancel(error)) return 'Đã huỷ tải.';
    return 'Lỗi tải xuống: ${error.message ?? error.type.name}';
  }
  return 'Đã có lỗi xảy ra, vui lòng thử lại.';
}

class YoutubeRepo {
  YoutubeRepo() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Video>> search(String query) async {
    final results = await _yt.search.search(query);
    return results.whereType<Video>().take(20).toList();
  }

  /// Get single video info from URL or ID.
  Future<Video?> getVideo(String urlOrId) async {
    try {
      return await _yt.videos.get(urlOrId);
    } catch (e) {
      debugPrint('getVideo error: $e');
      return null;
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Downloads the best audio stream for [video].
  /// Calls [onProgress] with 0.0–1.0 during download.
  /// Returns the saved [Song] on success, or throws.
  Future<Song> downloadAudio(
    Video video, {
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 1. Get stream manifest. youtube_explode_dart sets no timeout of its own,
    // so a stalled connection (flaky network, carrier interference, etc.)
    // would otherwise hang here forever instead of failing.
    final manifest = await _yt.videos.streamsClient
        .getManifest(video.id)
        .timeout(const Duration(seconds: 20));
    final audioStreams = manifest.audioOnly.toList();

    if (audioStreams.isEmpty) throw Exception('Không tìm thấy luồng âm thanh');

    // Prefer MP4/AAC (natively playable on Android) over WebM/Opus
    final mp4Streams = audioStreams.where(
      (s) => s.container.name.toLowerCase() == 'mp4',
    ).toList();

    AudioOnlyStreamInfo chosen;
    if (mp4Streams.isNotEmpty) {
      chosen = mp4Streams.reduce(
          (a, b) => a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b);
    } else {
      chosen = audioStreams.reduce(
          (a, b) => a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b);
    }

    final ext = chosen.container.name.toLowerCase() == 'mp4' ? 'm4a' : 'webm';

    // 2. Prepare output path
    final dir = await _musicDir();
    final safeName = _safeName(video.title);
    final filePath = p.join(dir.path, '$safeName.${video.id.value}.$ext');

    // 3. Download with progress, via youtube_explode_dart's own HTTP client
    // (a raw request to `chosen.url` from an unrelated client is what YouTube
    // returns 403 for — the stream URL is tied to that client's session).
    final total = chosen.size.totalBytes;
    var received = 0;
    final file = File(filePath);
    final sink = file.openWrite();
    final stream = _yt.videos.streamsClient.get(chosen);
    final completer = Completer<void>();
    late final StreamSubscription<List<int>> sub;

    // youtube_explode_dart's stream never times out on its own either — if
    // the connection stalls (no bytes for a while, including the very first
    // one), fail instead of hanging indefinitely.
    Timer? stallTimer;
    void resetStallTimer() {
      stallTimer?.cancel();
      stallTimer = Timer(const Duration(seconds: 20), () {
        if (completer.isCompleted) return;
        sub.cancel();
        sink.close();
        completer.completeError(TimeoutException('Stalled download stream'));
      });
    }

    void finishWithCancel() {
      if (completer.isCompleted) return;
      stallTimer?.cancel();
      sub.cancel();
      sink.close();
      completer.completeError(
        cancelToken!.cancelError ??
            DioException.requestCancelled(
              requestOptions: RequestOptions(),
              reason: 'Đã huỷ',
            ),
      );
    }

    cancelToken?.whenCancel.then((_) => finishWithCancel());

    resetStallTimer();
    sub = stream.listen(
      (chunk) {
        resetStallTimer();
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      },
      onDone: () async {
        if (completer.isCompleted) return;
        stallTimer?.cancel();
        await sink.close();
        completer.complete();
      },
      onError: (Object e, StackTrace st) {
        if (completer.isCompleted) return;
        stallTimer?.cancel();
        sink.close();
        completer.completeError(e, st);
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }

    // 4. Build Song and save to Hive
    final song = Song(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      album: 'YouTube',
      filePath: filePath,
      durationMs: video.duration?.inMilliseconds ?? 0,
      addedAt: DateTime.now(),
    );

    await HiveBoxes.songs.put(song.id, song);
    return song;
  }

  Future<void> cancelDownload(CancelToken token) async {
    token.cancel('Người dùng huỷ');
  }

  Future<Directory> _musicDir() async {
    // The app's own external-files directory (e.g.
    // /storage/emulated/0/Android/data/<package>/files) needs no runtime
    // storage permission and is always writable, unlike the public Music
    // folder, which Scoped Storage blocks writes to on Android 11+ without
    // MANAGE_EXTERNAL_STORAGE (not something a normal app should request).
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'MusicPlayer'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

  void dispose() {
    _yt.close();
  }
}
