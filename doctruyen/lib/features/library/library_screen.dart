import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../domain/models/book.dart';
import '../drive/drive_provider.dart';
import '../drive/drive_ui.dart';
import '../import/import_controller.dart';
import '../reader/reader_screen.dart';
import '../stats/stats_screen.dart';
import '../tts/tts_settings_sheet.dart';
import 'book_cover.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mở app: tự cập nhật truyện/chương mới từ thư mục Drive chung.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLibrary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại app sau một lúc: cập nhật lại (tối đa 10 phút/lần).
    if (state == AppLifecycleState.resumed) _syncLibrary();
  }

  void _syncLibrary({bool manual = false}) {
    if (!mounted) return;
    unawaited(
      DriveUi.syncLibrary(ScaffoldMessenger.of(context), ref, manual: manual),
    );
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      ref.read(bookQueryProvider.notifier).set('');
    }
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id)),
    );
    if (mounted) await ref.read(libraryProvider.notifier).refresh();
  }

  /// Kéo để làm mới = bấm "Cập nhật": đồng bộ kỹ với thư mục Drive chung.
  Future<void> _refresh() =>
      DriveUi.syncLibrary(ScaffoldMessenger.of(context), ref, manual: true);

  Future<void> _restoreHidden() async {
    await ref.read(librarySyncProvider.notifier).restoreIgnored();
    _syncLibrary(manual: true);
  }

  Future<void> _onBookMenu(Book book, String action) async {
    if (action == 'drive') {
      await DriveUi.syncNow(context, ref, book);
    } else {
      await _confirmDelete(book);
    }
  }

  Future<void> _confirmDelete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa truyện?'),
        content: Text(
          'Xóa "${book.displayTitle}" cùng tiến độ đọc, dấu trang và thống kê của truyện này?'
          '${book.isDrive ? '\n\nTruyện sẽ không tự tải lại khi cập nhật (có thể hiện lại trong menu).' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (book.isDrive) {
      await ref.read(librarySyncProvider.notifier).ignore(book.driveFolderId);
    }
    await ref.read(libraryProvider.notifier).delete(book.id);
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(visibleBooksProvider);
    final sort = ref.watch(bookSortProvider);
    final sync = ref.watch(librarySyncProvider);
    final hiddenCount = ref
        .read(librarySyncProvider.notifier)
        .ignoredFolders
        .length;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên truyện...',
                  border: InputBorder.none,
                ),
                onChanged: ref.read(bookQueryProvider.notifier).set,
              )
            : const Text('Thư viện'),
        bottom: sync.running ? _SyncProgressBar(state: sync) : null,
        actions: [
          IconButton(
            tooltip: sync.running ? 'Đang cập nhật...' : 'Cập nhật truyện',
            icon: const Icon(Icons.sync),
            onPressed: sync.running ? null : () => _syncLibrary(manual: true),
          ),
          IconButton(
            tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm truyện',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'recent':
                  ref.read(bookSortProvider.notifier).set(BookSort.recent);
                case 'title':
                  ref.read(bookSortProvider.notifier).set(BookSort.title);
                case 'stats':
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                case 'tts':
                  showTtsSettingsSheet(context);
                case 'restore':
                  unawaited(_restoreHidden());
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'recent',
                checked: sort == BookSort.recent,
                child: const Text('Sắp xếp: đọc gần đây'),
              ),
              CheckedPopupMenuItem(
                value: 'title',
                checked: sort == BookSort.title,
                child: const Text('Sắp xếp: theo tên'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'stats', child: Text('Thống kê đọc')),
              const PopupMenuItem(value: 'tts', child: Text('Giọng đọc (TTS)')),
              if (hiddenCount > 0)
                PopupMenuItem(
                  value: 'restore',
                  child: Text('Hiện lại truyện đã xóa ($hiddenCount)'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ImportController.pickAndImport(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nhập tệp'),
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải thư viện: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(
              searching: ref.watch(bookQueryProvider).isNotEmpty,
              syncing: sync.running,
              onSync: () => _syncLibrary(manual: true),
            );
          }
          final now = DateTime.now();
          final updates = ref.watch(driveUpdatesProvider);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final b = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openBook(b),
                  onLongPress: () => _confirmDelete(b),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BookCover(title: b.title),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: b.title),
                                    if (updates.containsKey(b.id))
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: _UpdateBadge(
                                            count: updates[b.id]!.newChapters,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (b.volume.isNotEmpty)
                                Text(
                                  b.volume,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: b.progress,
                                minHeight: 5,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(b.progress * 100).round()}% · ${b.chapterCount} chương · ${Fmt.relative(b.lastReadAt, now)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Tùy chọn',
                          onSelected: (a) => _onBookMenu(b, a),
                          itemBuilder: (_) => [
                            if (b.isDrive)
                              const PopupMenuItem(
                                value: 'drive',
                                child: Text('Cập nhật từ Drive'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa truyện'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 0 ? '+$count mới' : 'Có cập nhật',
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Thanh tiến độ dưới AppBar khi đang đồng bộ thư viện.
class _SyncProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const _SyncProgressBar({required this.state});

  final LibrarySyncState state;

  @override
  Size get preferredSize => const Size.fromHeight(24);

  @override
  Widget build(BuildContext context) {
    final s = state;
    final label = s.total == 0
        ? 'Đang kiểm tra truyện mới...'
        : 'Cập nhật ${s.index + 1}/${s.total}: ${s.title}'
              '${s.chapters > 0 ? ' (${s.done}/${s.chapters} chương)' : ''}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: s.fraction, minHeight: 3),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.syncing,
    required this.onSync,
  });

  final bool searching;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.menu_book_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'Không có truyện khớp.'
                  : syncing
                  ? 'Đang tải truyện từ thư viện chung...'
                  : 'Thư viện còn trống.\nBấm "Cập nhật" để tải truyện từ thư viện chung, '
                        'hoặc "Nhập tệp" để thêm tệp .zip, .txt, .epub, .md trên máy.',
              textAlign: TextAlign.center,
            ),
            if (!searching && !syncing) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Cập nhật'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
