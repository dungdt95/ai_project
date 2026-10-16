import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/player_provider.dart';
import '../data/local_music_repo.dart';
import '../domain/song.dart';
import '../../player/presentation/now_playing_screen.dart';
import 'playlist/playlist_screen.dart';
import 'widgets/song_tile.dart';
import 'widgets/mini_player.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _repo = LocalMusicRepo();
  bool _loading = false;
  String _search = '';
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    Future.microtask(_loadFromDb);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _loadFromDb() {
    final songs = _repo.getAllSongs();
    ref.read(libraryProvider.notifier).setSongs(songs);
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final found = await _repo.scanStorage();
    if (found.isNotEmpty) {
      ref.read(libraryProvider.notifier).addSongs(found);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tìm thấy ${found.length} bài mới')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không tìm thấy bài nào mới')));
    }
    setState(() => _loading = false);
  }

  Future<void> _pickFiles() async {
    setState(() => _loading = true);
    final added = await _repo.pickFiles();
    if (added.isNotEmpty) ref.read(libraryProvider.notifier).addSongs(added);
    setState(() => _loading = false);
  }

  void _playSong(List<Song> songs, int index) {
    ref.read(playerProvider.notifier).playSong(songs, index);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final allSongs = ref.watch(libraryProvider);
    final sortMode = ref.read(libraryProvider.notifier).sortMode;
    final q = _search.toLowerCase();
    final songs = q.isEmpty
        ? allSongs
        : allSongs
            .where((s) =>
                s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q))
            .toList();
    final player = ref.watch(playerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF1DB954),
          labelColor: const Color(0xFF1DB954),
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Bài hát'), Tab(text: 'Playlist')],
        ),
        actions: [
          // Sort menu
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            color: const Color(0xFF282828),
            onSelected: (m) => ref.read(libraryProvider.notifier).setSort(m),
            itemBuilder: (_) => [
              _sortItem(SortMode.title, 'Tên bài hát', sortMode),
              _sortItem(SortMode.artist, 'Nghệ sĩ', sortMode),
              _sortItem(SortMode.recentlyAdded, 'Mới thêm', sortMode),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else ...[
            IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: 'Chọn file',
                onPressed: _pickFiles),
            IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Quét nhạc',
                onPressed: _scan),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search bar (only on songs tab)
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) => _tabCtrl.index == 0
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm bài hát, nghệ sĩ...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                })
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF282828),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Songs tab ──────────────────────────────────────────────
                songs.isEmpty
                    ? _EmptyState(onPick: _pickFiles, onScan: _scan)
                    : ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (ctx, i) => SongTile(
                          song: songs[i],
                          isPlaying:
                              player.currentSong?.id == songs[i].id && player.isPlaying,
                          onTap: () => _playSong(songs, i),
                          onRemove: () async {
                            await _repo.removeSong(songs[i].id);
                            ref.read(libraryProvider.notifier).removeSong(songs[i].id);
                          },
                        ),
                      ),

                // ── Playlist tab ───────────────────────────────────────────
                const SingleChildScrollView(child: PlaylistScreen()),
              ],
            ),
          ),

          if (player.currentSong != null)
            MiniPlayer(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NowPlayingScreen())),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<SortMode> _sortItem(SortMode mode, String label, SortMode current) =>
      PopupMenuItem(
        value: mode,
        child: Row(children: [
          Icon(current == mode ? Icons.radio_button_checked : Icons.radio_button_off,
              color: const Color(0xFF1DB954), size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick, required this.onScan});
  final VoidCallback onPick;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Chưa có bài hát nào',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.folder_open),
            label: const Text('Chọn file âm nhạc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.search, color: Colors.white54),
            label: const Text('Quét toàn bộ máy',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
