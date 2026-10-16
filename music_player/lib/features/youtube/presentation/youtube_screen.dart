import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/audio/player_provider.dart';
import '../data/youtube_repo.dart' show YoutubeRepo, friendlyYoutubeErrorMessage;
import '../../player/presentation/now_playing_screen.dart';
import '../../library/presentation/widgets/mini_player.dart';
import 'download_notifier.dart';
import 'widgets/video_result_tile.dart';
import 'widgets/download_list.dart';

class YoutubeScreen extends ConsumerStatefulWidget {
  const YoutubeScreen({super.key});

  @override
  ConsumerState<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends ConsumerState<YoutubeScreen> {
  final _repo = YoutubeRepo();
  final _searchCtrl = TextEditingController();

  List<Video> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      // Check if it's a YouTube URL
      final isUrl = query.contains('youtube.com') || query.contains('youtu.be');
      if (isUrl) {
        final video = await _repo.getVideo(query);
        setState(() { _results = video != null ? [video] : []; });
      } else {
        final results = await _repo.search(query);
        setState(() { _results = results; });
      }
    } catch (e) {
      setState(() { _error = friendlyYoutubeErrorMessage(e); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final downloads = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm hoặc dán link YouTube...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))),
                      )
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF1DB954)),
                            onPressed: () => _search(_searchCtrl.text),
                          )
                        : null,
                filled: true,
                fillColor: const Color(0xFF282828),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Active / completed downloads
          DownloadList(),

          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),

          // Search results
          Expanded(
            child: _results.isEmpty && !_loading
                ? _EmptyHint()
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final video = _results[i];
                      final task = downloads[video.id.value];
                      return VideoResultTile(
                        video: video,
                        task: task,
                        onDownload: () =>
                            ref.read(downloadProvider.notifier).startDownload(video),
                      );
                    },
                  ),
          ),

          if (player.currentSong != null)
            MiniPlayer(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, size: 72, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Tìm bài hát trên YouTube',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Hoặc dán link video để tải về',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}
