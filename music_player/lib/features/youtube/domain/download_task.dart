enum DownloadStatus { pending, downloading, done, error }

class DownloadTask {
  DownloadTask({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.durationSeconds,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMsg,
    this.filePath,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int? durationSeconds;

  DownloadStatus status;
  double progress;
  String? errorMsg;
  String? filePath;

  bool get isDone => status == DownloadStatus.done;
  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.pending;

  String get durationLabel {
    if (durationSeconds == null) return '';
    final m = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMsg,
    String? filePath,
  }) => DownloadTask(
    videoId: videoId,
    title: title,
    author: author,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    errorMsg: errorMsg ?? this.errorMsg,
    filePath: filePath ?? this.filePath,
  );
}
