import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/player_provider.dart';
import '../../domain/playlist.dart';
import '../../../player/presentation/now_playing_screen.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playlistProvider); // rebuild on changes
    final allSongs = ref.watch(libraryProvider);
    final songs = ref.read(playlistProvider.notifier).getSongs(playlist.id, allSongs);
    final player = ref.watch(playerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: () async {
                songs.shuffle();
                await ref.read(playerProvider.notifier).playSong(songs, 0);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                  );
                }
              },
            ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(
              child: Text('Playlist trống.\nThêm bài từ Thư viện.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38)),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (ctx, i) => SongTile(
                song: songs[i],
                isPlaying: player.currentSong?.id == songs[i].id && player.isPlaying,
                onTap: () async {
                  await ref.read(playerProvider.notifier).playSong(songs, i);
                  if (ctx.mounted) {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                    );
                  }
                },
                onRemove: () =>
                    ref.read(playlistProvider.notifier).removeSong(playlist.id, songs[i].id),
                removeLabel: 'Xoá khỏi playlist',
              ),
            ),
    );
  }
}
