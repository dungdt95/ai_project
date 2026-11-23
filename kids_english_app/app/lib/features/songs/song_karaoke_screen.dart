import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
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
  int _activeIndex = -1;
  bool _isPlaying = false;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _startSong();
  }

  void _startSong() {
    _isPlaying = true;
    _currentSeconds = 0;
    _activeIndex = -1;
    _posSub?.cancel();
    _stateSub?.cancel();
    _fallbackTimer?.cancel();

    final audio = ref.read(audioProvider);
    final lyricsText = widget.song.lyrics.map((l) => l.text).join(" ");
    audio.play(widget.song.audio, lyricsText, baseDir: widget.baseDir);

    // Lắng nghe vị trí phát nhạc theo thời gian thực (real-time stream)
    _posSub = audio.positionStream.listen((pos) {
      if (!mounted) return;
      _fallbackTimer?.cancel();
      final sec = pos.inSeconds;
      if (sec != _currentSeconds) {
        print('>>> [Karaoke] Real-time audio pos: ${pos.inMilliseconds}ms -> sec: $sec');
        _updatePosition(sec);
      }
    });

    _stateSub = audio.playerStateStream.listen((state) {
      if (!mounted) return;
      print('>>> [Karaoke] Audio player state: ${state.processingState}, playing: ${state.playing}');
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });

    // Fallback timer (chỉ chạy nếu positionStream không phát tín hiệu sau 2 giây)
    _fallbackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isPlaying) return;
      print('>>> [Karaoke] WARNING: positionStream not received, using fallback timer');
      _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isPlaying) return;
        if (_currentSeconds < 45) {
          _updatePosition(_currentSeconds + 1);
        } else {
          _fallbackTimer?.cancel();
          setState(() => _isPlaying = false);
        }
      });
    });
  }

  void _updatePosition(int sec) {
    int idx = -1;
    for (var i = 0; i < widget.song.lyrics.length; i++) {
      if (sec >= widget.song.lyrics[i].t) {
        idx = i;
      }
    }

    if (idx != _activeIndex || sec != _currentSeconds) {
      setState(() {
        _currentSeconds = sec;
        _activeIndex = idx;
      });

      // Tự động cuộn danh sách lời bài hát đưa câu đang hát ra giữa màn hình
      if (idx >= 0 && _scrollController.hasClients) {
        final targetOffset = (idx * 56.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _replay() {
    _startSong();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _fallbackTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIntro = _currentSeconds < (widget.song.lyrics.isNotEmpty ? widget.song.lyrics.first.t : 4);

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
                  // Bìa bài hát + linh vật nhảy theo nhạc
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
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (isIntro)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🎶 ', style: TextStyle(fontSize: 20)),
                                  Text(
                                    'Music Intro... Ready to sing in ${4 - _currentSeconds}s! 🎵',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().scale(duration: 300.ms),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: widget.song.lyrics.length,
                              itemBuilder: (ctx, i) {
                                final line = widget.song.lyrics[i];
                                final isCurrent = i == _activeIndex;
                                final isPast = i < _activeIndex;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
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
                        ],
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
