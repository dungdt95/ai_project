import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../domain/models/book.dart';

/// Nơi cần nhảy tới trong truyện.
class JumpTarget {
  const JumpTarget(this.chapterId, this.paragraph);

  final int chapterId;
  final int paragraph;
}

Future<JumpTarget?> showTocSheet(
  BuildContext context, {
  required Book book,
  required List<ChapterInfo> chapters,
  required List<Arc> arcs,
  required int currentChapterId,
}) {
  return showModalBottomSheet<JumpTarget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _TocSheet(
        book: book,
        chapters: chapters,
        arcs: arcs,
        currentChapterId: currentChapterId,
        scrollController: scroll,
      ),
    ),
  );
}

class _TocSheet extends ConsumerStatefulWidget {
  const _TocSheet({
    required this.book,
    required this.chapters,
    required this.arcs,
    required this.currentChapterId,
    required this.scrollController,
  });

  final Book book;
  final List<ChapterInfo> chapters;
  final List<Arc> arcs;
  final int currentChapterId;
  final ScrollController scrollController;

  @override
  ConsumerState<_TocSheet> createState() => _TocSheetState();
}

class _TocSheetState extends ConsumerState<_TocSheet> {
  List<Bookmark>? _bookmarks;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final list = await ref
        .read(libraryRepositoryProvider)
        .bookmarks(widget.book.id);
    if (mounted) setState(() => _bookmarks = list);
  }

  Widget _chapterTile(ChapterInfo c) {
    final current = c.id == widget.currentChapterId;
    return ListTile(
      dense: true,
      selected: current,
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: c.finished ? const Icon(Icons.check_circle, size: 18) : null,
      onTap: () => Navigator.pop(context, JumpTarget(c.id, 0)),
    );
  }

  List<Widget> _tocChildren() {
    if (widget.arcs.isEmpty) return widget.chapters.map(_chapterTile).toList();
    final used = <int>{};
    final out = <Widget>[];
    for (final arc in widget.arcs) {
      final inArc = widget.chapters
          .where((c) => arc.contains(c.number))
          .toList();
      if (inArc.isEmpty) continue;
      used.addAll(inArc.map((c) => c.id));
      out.add(
        ExpansionTile(
          initiallyExpanded: inArc.any((c) => c.id == widget.currentChapterId),
          title: Text(arc.name),
          subtitle: Text('${inArc.length} chương'),
          children: inArc.map(_chapterTile).toList(),
        ),
      );
    }
    final rest = widget.chapters.where((c) => !used.contains(c.id)).toList();
    if (rest.isNotEmpty) {
      out.add(
        ExpansionTile(
          title: const Text('Khác'),
          children: rest.map(_chapterTile).toList(),
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Mục lục'),
              Tab(text: 'Dấu trang'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  controller: widget.scrollController,
                  children: _tocChildren(),
                ),
                _bookmarkList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookmarkList() {
    final list = _bookmarks;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dấu trang.\nBấm biểu tượng dấu trang khi đang đọc.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final b = list[i];
        return ListTile(
          leading: const Icon(Icons.bookmark),
          title: Text(b.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            b.chapterTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: 'Xóa dấu trang',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(libraryRepositoryProvider).deleteBookmark(b.id);
              await _loadBookmarks();
            },
          ),
          onTap: () =>
              Navigator.pop(context, JumpTarget(b.chapterId, b.paragraph)),
        );
      },
    );
  }
}
