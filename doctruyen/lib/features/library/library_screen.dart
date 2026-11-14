import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../domain/models/book.dart';
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

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _confirmDelete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa truyện?'),
        content: Text(
          'Xóa "${book.displayTitle}" cùng tiến độ đọc, dấu trang và thống kê của truyện này?',
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
    if (ok == true) await ref.read(libraryProvider.notifier).delete(book.id);
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(visibleBooksProvider);
    final sort = ref.watch(bookSortProvider);

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
        actions: [
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
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ImportController.pickAndImport(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nhập truyện'),
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải thư viện: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(
              searching: ref.watch(bookQueryProvider).isNotEmpty,
            );
          }
          final now = DateTime.now();
          return ListView.separated(
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
                            Text(
                              b.title,
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
                        onSelected: (_) => _confirmDelete(b),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
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
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

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
              searching ? 'Không có truyện khớp.' : 'Thư viện còn trống.\nBấm "Nhập truyện" để thêm tệp .zip, .txt hoặc .epub.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
