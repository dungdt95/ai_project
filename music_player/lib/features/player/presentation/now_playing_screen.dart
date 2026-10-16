import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../core/audio/player_provider.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Color _bgColor = const Color(0xFF1A3A2A);
  String? _lastArtPath;
  bool _showQueue = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateBgColor();
  }

  Future<void> _updateBgColor() async {
    final song = ref.read(playerProvider).currentSong;
    final artPath = song?.artworkPath;
    if (artPath == null || artPath == _lastArtPath) return;
    if (!File(artPath).existsSync()) return;
    _lastArtPath = artPath;

    try {
      final gen = await PaletteGenerator.fromImageProvider(
        FileImage(File(artPath)),
        size: const Size(100, 100),
      );
      final color = gen.dominantColor?.color ?? gen.vibrantColor?.color;
      if (color != null && mounted) {
        setState(() => _bgColor = color.withOpacity(0.85));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    // Update bg when song changes
    if (song?.artworkPath != _lastArtPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateBgColor());
    }

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Không có bài hát')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Đang phát',
            style: TextStyle(fontSize: 14, color: Colors.white60)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showQueue ? Icons.queue_music : Icons.queue_music_outlined,
                color: _showQueue ? const Color(0xFF1DB954) : Colors.white60),
            onPressed: () => setState(() => _showQueue = !_showQueue),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgColor.withOpacity(0.9), const Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: _showQueue
              ? _QueueView(state: state)
              : _PlayerView(state: state),
        ),
      ),
    );
  }
}

// ── Main player view ──────────────────────────────────────────────────────────

class _PlayerView extends StatelessWidget {
  const _PlayerView({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final song = state.currentSong!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _AlbumArt(artPath: song.artworkPath, isPlaying: state.isPlaying),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(song.artist,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white60, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SeekBar(state: state),
          const SizedBox(height: 16),
          _Controls(state: state),
          const SizedBox(height: 16),
          Text('${state.currentIndex + 1} / ${state.queue.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Queue view ────────────────────────────────────────────────────────────────

class _QueueView extends ConsumerWidget {
  const _QueueView({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text('Danh sách phát',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.queue.length,
            itemBuilder: (ctx, i) {
              final song = state.queue[i];
              final isCurrent = i == state.currentIndex;
              return ListTile(
                leading: isCurrent
                    ? const Icon(Icons.equalizer, color: Color(0xFF1DB954))
                    : Text('${i + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 14)),
                title: Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14)),
                subtitle: Text(song.artist,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => ref.read(playerProvider.notifier).skipToIndex(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Album art ─────────────────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({this.artPath, required this.isPlaying});
  final String? artPath;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    Widget art;
    if (artPath != null && File(artPath!).existsSync()) {
      art = Image.file(File(artPath!), fit: BoxFit.cover);
    } else {
      art = Container(
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 80),
      );
    }

    return AnimatedScale(
      scale: isPlaying ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5),
                blurRadius: 30, offset: const Offset(0, 15)),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: art),
      ),
    );
  }
}

// ── Seek bar ──────────────────────────────────────────────────────────────────

class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.state});
  final PlayerState state;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragging;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.state.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final pos = (_dragging ?? widget.state.position.inMilliseconds.toDouble()).clamp(0.0, total);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: const Color(0xFF1DB954),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: pos,
            min: 0,
            max: total,
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              ref.read(playerProvider.notifier).seek(Duration(milliseconds: v.toInt()));
              setState(() => _dragging = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(Duration(milliseconds: pos.toInt())),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_fmt(widget.state.duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _Controls extends ConsumerWidget {
  const _Controls({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(playerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle,
              color: state.shuffle ? const Color(0xFF1DB954) : Colors.white54),
          onPressed: n.toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
          onPressed: n.previous,
        ),
        GestureDetector(
          onTap: n.togglePlay,
          child: Container(
            width: 68, height: 68,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF1DB954)),
            child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 38),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
          onPressed: n.next,
        ),
        IconButton(
          icon: Icon(
            state.repeatMode == AudioServiceRepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
            color: state.repeatMode != AudioServiceRepeatMode.none
                ? const Color(0xFF1DB954)
                : Colors.white54,
          ),
          onPressed: n.cycleRepeat,
        ),
      ],
    );
  }
}
