import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../domain/text/book_search.dart';
import 'toc_sheet.dart';

/// Tìm văn bản trong cả truyện; trả về [JumpTarget] khi chọn kết quả.
class BookSearchScreen extends ConsumerStatefulWidget {
  const BookSearchScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends ConsumerState<BookSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchHit>? _hits;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.length < 2) return;
    setState(() => _busy = true);
    final hits = await ref
        .read(libraryRepositoryProvider)
        .searchInBook(widget.bookId, q);
    if (mounted) {
      setState(() {
        _hits = hits;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Tìm trong truyện...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _run(),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: _run)],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : hits == null
          ? const Center(
              child: Text('Nhập từ khóa (không cần gõ dấu) rồi bấm tìm.'),
            )
          : hits.isEmpty
          ? const Center(child: Text('Không tìm thấy.'))
          : ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final h = hits[i];
                return ListTile(
                  title: Text(
                    h.snippet,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    h.chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(
                    context,
                    JumpTarget(h.chapterId, h.paragraph),
                  ),
                );
              },
            ),
    );
  }
}
