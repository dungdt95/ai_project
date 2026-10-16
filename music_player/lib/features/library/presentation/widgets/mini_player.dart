import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFF181818),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress line
            LinearProgressIndicator(
              value: state.duration.inMilliseconds > 0
                  ? state.position.inMilliseconds / state.duration.inMilliseconds
                  : 0,
              minHeight: 2,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1DB954)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 40, height: 40,
                      child: song.artworkPath != null && File(song.artworkPath!).existsSync()
                          ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFF333333),
                              child: const Icon(Icons.music_note, color: Colors.white38, size: 22),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Controls
                  IconButton(
                    icon: Icon(
                      state.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () => ref.read(playerProvider.notifier).togglePlay(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () => ref.read(playerProvider.notifier).next(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
