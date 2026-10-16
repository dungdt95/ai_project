import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/player_provider.dart';
import '../../domain/song.dart';

class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
    this.removeLabel = 'Xoá khỏi thư viện',
  });

  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);

    return ListTile(
      leading: _Artwork(path: song.artworkPath, isPlaying: isPlaying),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? const Color(0xFF1DB954) : Colors.white,
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(song.durationLabel,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          PopupMenuButton<String>(
            color: const Color(0xFF282828),
            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
            onSelected: (v) async {
              if (v == 'remove') {
                onRemove();
              } else if (v.startsWith('pl:')) {
                final playlistId = v.substring(3);
                await ref.read(playlistProvider.notifier).addSong(playlistId, song.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thêm vào playlist'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              // Add to playlist submenu
              if (playlists.isNotEmpty) ...[
                const PopupMenuItem(
                  enabled: false,
                  height: 28,
                  child: Text('Thêm vào playlist',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
                ...playlists.map((p) => PopupMenuItem(
                  value: 'pl:${p.id}',
                  child: Text(p.name, style: const TextStyle(color: Colors.white)),
                )),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(removeLabel, style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.path, required this.isPlaying});
  final String? path;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    Widget art;
    if (path != null && File(path!).existsSync()) {
      art = Image.file(File(path!), fit: BoxFit.cover);
    } else {
      art = Container(
        color: const Color(0xFF333333),
        child: const Icon(Icons.music_note, color: Colors.white38, size: 28),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48, height: 48,
        child: Stack(children: [
          Positioned.fill(child: art),
          if (isPlaying)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Icon(Icons.equalizer, color: Color(0xFF1DB954)),
              ),
            ),
        ]),
      ),
    );
  }
}
