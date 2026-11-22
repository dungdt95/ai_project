import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class SongKaraokeScreen extends ConsumerStatefulWidget {
  const SongKaraokeScreen({
    super.key,
    required this.song,
    required this.baseDir,
  });

  final Song song;
  final String? baseDir;

  @override
  ConsumerState<SongKaraokeScreen> createState() => _SongKaraokeScreenState();
}

class _SongKaraokeScreenState extends ConsumerState<SongKaraokeScreen> {
  int _currentSeconds = 0;
  Timer? _songTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _startSong();
  }

  void _startSong() {
    _isPlaying = true;
    _currentSeconds = 0;
    _songTimer?.cancel();

    // Hát bằng AudioService
    final audio = ref.read(audioProvider);
    final lyricsText = widget.song.lyrics.map((l) => l.text).join(" ");
    audio.play(widget.song.audio, lyricsText, baseDir: widget.baseDir);

    _songTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _currentSeconds++;
        if (_currentSeconds >= 45) {
          _songTimer?.cancel();
          _isPlaying = false;
        }
      });
    });
  }

  void _replay() {
    _startSong();
  }

  @override
  void dispose() {
    _songTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Xác định dòng lyric hiện tại dựa vào mốc thời gian t
    int activeIndex = -1;
    for (var i = 0; i < widget.song.lyrics.length; i++) {
      if (_currentSeconds >= widget.song.lyrics[i].t) {
        activeIndex = i;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.sky,
      body: SafeArea(
        child: Stack(
          children: [
            // Nút Back
            Positioned(
              left: 16,
              top: 12,
              child: IconButton.filled(
                iconSize: 32,
                style: IconButton.styleFrom(backgroundColor: Colors.white70),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () {
                  ref.read(audioProvider).stop();
                  context.pop();
                },
              ),
            ),

            // Tiêu đề bài hát
            Positioned(
              top: 16,
              left: 80,
              right: 80,
              child: Text(
                widget.song.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),

            // Khu vực trình bày: Bìa bài hát (Trái) + Lời Karaoke chạy (Phải)
            Positioned.fill(
              top: 70,
              bottom: 20,
              left: 32,
              right: 32,
              child: Row(
                children: [
                  // Bìa bài hát + linh vật hát
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: MediaImage(
                              widget.song.cover,
                              baseDir: widget.baseDir,
                              label: widget.song.title,
                            ),
                          )
                              .animate(target: _isPlaying ? 1 : 0)
                              .shake(duration: 2.seconds, hz: 1, curve: Curves.easeInOut),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                onPressed: _replay,
                                icon: const Icon(Icons.replay_rounded, size: 28),
                                label: const Text("Replay", style: TextStyle(fontSize: 20)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Danh sách lời bài hát Karaoke
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: ListView.builder(
                        itemCount: widget.song.lyrics.length,
                        itemBuilder: (ctx, i) {
                          final line = widget.song.lyrics[i];
                          final isCurrent = i == activeIndex;
                          final isPast = i < activeIndex;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AnimatedDefaultTextStyle(
                              duration: 300.ms,
                              style: TextStyle(
                                fontSize: isCurrent ? 28 : (isPast ? 20 : 20),
                                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                                color: isCurrent
                                    ? AppColors.orange
                                    : (isPast ? Colors.grey.shade600 : Colors.grey.shade400),
                              ),
                              child: Row(
                                children: [
                                  if (isCurrent)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Text('🎵', style: TextStyle(fontSize: 24)),
                                    ),
                                  Expanded(child: Text(line.text)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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
