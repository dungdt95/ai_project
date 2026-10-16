import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../download_notifier.dart';
import '../../domain/download_task.dart';

class DownloadList extends ConsumerWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider).values.toList().reversed.toList();
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Đang tải / Đã tải',
              style: TextStyle(color: Colors.white54, fontSize: 12,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        ...tasks.map((t) => _DownloadItem(task: t)),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }
}

class _DownloadItem extends ConsumerWidget {
  const _DownloadItem({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: _statusIcon(task.status),
      title: Text(task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: task.status == DownloadStatus.downloading
          ? LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1DB954)),
              minHeight: 2,
            )
          : Text(
              task.status == DownloadStatus.done
                  ? 'Đã xong • ${task.author}'
                  : task.errorMsg ?? 'Lỗi',
              style: TextStyle(
                color: task.status == DownloadStatus.error
                    ? Colors.redAccent
                    : Colors.white38,
                fontSize: 11,
              ),
            ),
      trailing: task.status != DownloadStatus.downloading
          ? IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              onPressed: () => ref.read(downloadProvider.notifier).remove(task.videoId),
            )
          : IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.white38),
              onPressed: () => ref.read(downloadProvider.notifier).cancel(task.videoId),
            ),
    );
  }

  Widget _statusIcon(DownloadStatus s) {
    return switch (s) {
      DownloadStatus.done       => const Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 22),
      DownloadStatus.error      => const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
      DownloadStatus.downloading => const SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))),
      DownloadStatus.pending    => const Icon(Icons.schedule, color: Colors.white38, size: 22),
    };
  }
}
