import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/vn_text.dart';
import '../../data/data_providers.dart';
import '../../domain/models/book.dart';

enum BookSort { recent, title }

class BookSortNotifier extends Notifier<BookSort> {
  @override
  BookSort build() => BookSort.recent;

  void set(BookSort s) => state = s;
}

final bookSortProvider = NotifierProvider<BookSortNotifier, BookSort>(
  BookSortNotifier.new,
);

class BookQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q;
}

final bookQueryProvider = NotifierProvider<BookQueryNotifier, String>(
  BookQueryNotifier.new,
);

class LibraryNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() =>
      ref.watch(libraryRepositoryProvider).listBooks();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(libraryRepositoryProvider).listBooks());
  }

  Future<void> delete(int id) async {
    await ref.read(libraryRepositoryProvider).deleteBook(id);
    await refresh();
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<Book>>(
  LibraryNotifier.new,
);

/// Danh sách sau khi lọc theo tìm kiếm và sắp xếp.
final visibleBooksProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final books = ref.watch(libraryProvider);
  final sort = ref.watch(bookSortProvider);
  final query = VnText.normalize(ref.watch(bookQueryProvider).trim());
  return books.whenData((list) {
    final filtered = query.isEmpty
        ? [...list]
        : list
              .where((b) => VnText.normalize(b.displayTitle).contains(query))
              .toList();
    if (sort == BookSort.title) {
      filtered.sort(
        (a, b) =>
            VnText.normalize(a.title).compareTo(VnText.normalize(b.title)),
      );
    } else {
      filtered.sort((a, b) {
        final ta = a.lastReadAt ?? a.createdAt;
        final tb = b.lastReadAt ?? b.createdAt;
        return tb.compareTo(ta);
      });
    }
    return filtered;
  });
});
