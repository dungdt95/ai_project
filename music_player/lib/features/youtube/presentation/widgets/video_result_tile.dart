import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../domain/download_task.dart';

class VideoResultTile extends StatelessWidget {
  const VideoResultTile({
    super.key,
    required this.video,
    required this.task,
    required this.onDownload,
  });

  final Video video;
  final DownloadTask? task;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final isDownloading = task?.status == DownloadStatus.downloading;
    final isDone = task?.status == DownloadStatus.done;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: video.thumbnails.lowResUrl,
          width: 64, height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: const Color(0xFF333333),
            child: const Icon(Icons.music_video, color: Colors.white24),
          ),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF333333),
            child: const Icon(Icons.music_video, color: Colors.white24),
          ),
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      subtitle: Text(
        '${video.author}  ·  ${_fmtDuration(video.duration)}',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      trailing: _TrailingButton(
        task: task,
        isDownloading: isDownloading,
        isDone: isDone,
        onDownload: onDownload,
      ),
    );
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TrailingButton extends StatelessWidget {
  const _TrailingButton({
    this.task,
    required this.isDownloading,
    required this.isDone,
    required this.onDownload,
  });

  final DownloadTask? task;
  final bool isDownloading;
  final bool isDone;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return const Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 28);
    }
    if (isDownloading) {
      return SizedBox(
        width: 28, height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: task!.progress,
              strokeWidth: 2.5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1DB954)),
            ),
            Text(
              '${(task!.progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ],
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download, color: Color(0xFF1DB954)),
      onPressed: onDownload,
    );
  }
}
