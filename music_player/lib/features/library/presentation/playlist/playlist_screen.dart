import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/player_provider.dart';
import '../../domain/playlist.dart';
import 'playlist_detail_screen.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text('Playlist', style: TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF1DB954)),
                label: const Text('Tạo mới',
                    style: TextStyle(color: Color(0xFF1DB954), fontSize: 13)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có playlist nào',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else
          ...playlists.map((p) => _PlaylistTile(playlist: p)),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Tạo playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tên playlist',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1DB954))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(playlistProvider.notifier).create(name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Tạo', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = playlist.songIds.length;
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.queue_music, color: Color(0xFF1DB954)),
      ),
      title: Text(playlist.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text('$count bài',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: PopupMenuButton<String>(
        color: const Color(0xFF282828),
        icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
        onSelected: (v) async {
          if (v == 'delete') {
            await ref.read(playlistProvider.notifier).delete(playlist.id);
          } else if (v == 'rename') {
            _showRenameDialog(context, ref);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('Đổi tên',
              style: TextStyle(color: Colors.white))),
          const PopupMenuItem(value: 'delete', child: Text('Xoá',
              style: TextStyle(color: Colors.redAccent))),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: playlist)),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Đổi tên', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1DB954))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(playlistProvider.notifier).rename(playlist.id, name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}
