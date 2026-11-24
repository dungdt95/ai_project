import 'dart:async';

import '../data/dao/book_dao.dart';
import '../domain/drive/chapter_normalizer.dart';
import '../domain/drive/drive_models.dart';
import '../domain/drive/drive_plan.dart';
import '../domain/importers/parsed_book.dart';
import '../domain/models/book.dart';

/// Kết quả kiểm tra nhanh (không tải nội dung) xem Drive có gì mới.
class DriveCheck {
  const DriveCheck({
    required this.bookId,
    required this.newChapters,
    required this.changedChapters,
  });

  final int bookId;
  final int newChapters;
  final int changedChapters;

  bool get hasUpdates => newChapters > 0 || changedChapters > 0;
}

/// Kết quả một lần nhập/đồng bộ.
class DriveSyncReport {
  const DriveSyncReport({
    required this.bookId,
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.failed,
    required this.skipped,
    required this.isNewBook,
  });

  final int bookId;
  final int added;
  final int updated;
  final int unchanged;

  /// Số chương tải lỗi (sẽ được thử lại ở lần đồng bộ sau).
  final int failed;

  /// Số tệp bỏ qua vì không phải văn bản.
  final int skipped;
  final bool isNewBook;

  bool get nothingChanged => added == 0 && updated == 0;
}

typedef DriveProgress = void Function(int done, int total);

/// Tiến độ đồng bộ thư viện: đang xử lý truyện thứ [index] (từ 0) trên [total]
/// truyện, tên [title]; trong truyện đó đã tải [done]/[chapters] chương.
typedef LibraryProgress = void Function(
  String title,
  int index,
  int total,
  int done,
  int chapters,
);

/// Kết quả đồng bộ thư mục chung (mỗi thư mục con là một truyện).
class LibrarySyncReport {
  const LibrarySyncReport({
    required this.newBooks,
    required this.addedChapters,
    required this.updatedChapters,
    required this.failedChapters,
    required this.failedBooks,
    required this.syncedBookIds,
  });

  /// Tên các truyện mới được thêm vào thư viện.
  final List<String> newBooks;

  /// Chương mới của các truyện đã có (không tính chương của truyện mới).
  final int addedChapters;
  final int updatedChapters;
  final int failedChapters;

  /// Truyện không đồng bộ được (tên -> lý do).
  final Map<String, String> failedBooks;

  /// Truyện đã đồng bộ xong (để xóa dấu "có cập nhật").
  final List<int> syncedBookIds;

  bool get nothingChanged =>
      newBooks.isEmpty && addedChapters == 0 && updatedChapters == 0;
}

/// Nhập và đồng bộ truyện từ thư mục Google Drive.
class DriveSyncService {
  DriveSyncService(
    this._source,
    this._dao, {
    DateTime Function()? clock,
    this.concurrency = 4,
  }) : _clock = clock ?? DateTime.now;

  final DriveSource _source;
  final BookDao _dao;
  final DateTime Function() _clock;
  final int concurrency;

  static const List<String> _textExtensions = [
    '.md',
    '.markdown',
    '.txt',
    '.text',
  ];

  /// Kiểm tra nhẹ: chỉ tải danh sách thư mục, không tải chương.
  Future<DriveCheck> check(Book book) async {
    final listing = await _source.listFolder(book.driveFolderId);
    final plan = DrivePlan.compute(
      listing.entries,
      await _stored(book.id),
      existingNumbers: await _dao.chapterNumbers(book.id),
    );
    return DriveCheck(
      bookId: book.id,
      newChapters: plan.added.length,
      changedChapters: plan.changed.length,
    );
  }

  /// Nhập thư mục lần đầu; nếu thư mục đã có trong thư viện thì đồng bộ.
  Future<DriveSyncReport> importFolder(
    String folderId, {
    DriveProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final books = await _dao.listDriveBooks();
    final existing = books.where((b) => b.driveFolderId == folderId);
    return _run(
      folderId,
      existing.isEmpty ? null : existing.first.id,
      onProgress,
      cancel,
    );
  }

  /// Đồng bộ thư mục chung: mỗi thư mục con là một truyện. Thư mục mới được
  /// nhập thành truyện mới; truyện đã có được thêm chương mới, cập nhật chương
  /// đã sửa. Tệp nằm thẳng trong thư mục chung bị bỏ qua.
  ///
  /// [ignoredFolderIds]: thư mục truyện người dùng đã xóa khỏi thư viện.
  /// [thorough] = `false` (tự động khi mở app): chỉ tải chương chắc chắn mới
  /// hoặc đã sửa, bỏ qua chương có nhãn thời gian không chắc để tiết kiệm mạng.
  Future<LibrarySyncReport> syncLibrary(
    String rootFolderId, {
    Set<String> ignoredFolderIds = const {},
    bool thorough = true,
    LibraryProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final root = await _source.listFolder(rootFolderId);
    cancel?.throwIfCancelled();
    final folders = root.entries
        .where((e) => e.isFolder && !ignoredFolderIds.contains(e.id))
        .toList();
    final byFolder = {
      for (final b in await _dao.listDriveBooks()) b.driveFolderId: b,
    };

    final newBooks = <String>[];
    final failedBooks = <String, String>{};
    final synced = <int>[];
    var added = 0, updated = 0, failedChapters = 0;
    for (var i = 0; i < folders.length; i++) {
      cancel?.throwIfCancelled();
      final folder = folders[i];
      final existing = byFolder[folder.id];
      final title = existing?.title ?? folder.title;
      onProgress?.call(title, i, folders.length, 0, 0);
      try {
        final r = await _run(
          folder.id,
          existing?.id,
          (d, t) => onProgress?.call(title, i, folders.length, d, t),
          cancel,
          includeAmbiguous: thorough,
        );
        synced.add(r.bookId);
        if (r.isNewBook) {
          newBooks.add(folder.title);
        } else {
          added += r.added;
        }
        updated += r.updated;
        failedChapters += r.failed;
      } on DriveCancelledException {
        rethrow;
      } on DriveEmptyFolderException {
        // Thư mục truyện chưa có chương: bỏ qua, lần sau xét lại.
      } catch (e) {
        failedBooks[title] = e.toString();
      }
    }
    return LibrarySyncReport(
      newBooks: newBooks,
      addedChapters: added,
      updatedChapters: updated,
      failedChapters: failedChapters,
      failedBooks: failedBooks,
      syncedBookIds: synced,
    );
  }

  /// Đồng bộ ngay: thêm chương mới, cập nhật chương đổi nội dung.
  Future<DriveSyncReport> syncBook(
    Book book, {
    DriveProgress? onProgress,
    CancelToken? cancel,
  }) => _run(book.driveFolderId, book.id, onProgress, cancel);

  Future<List<StoredChapterRef>> _stored(int bookId) async => [
    for (final c in await _dao.driveChapters(bookId))
      StoredChapterRef(
        fileId: c.fileId,
        number: c.number,
        modified: c.modified,
        hash: c.hash,
      ),
  ];

  Future<DriveSyncReport> _run(
    String folderId,
    int? bookId,
    DriveProgress? onProgress,
    CancelToken? cancel, {
    bool includeAmbiguous = true,
  }) async {
    final listing = await _source.listFolder(folderId);
    cancel?.throwIfCancelled();
    final plan = DrivePlan.compute(
      listing.entries,
      bookId == null ? const [] : await _stored(bookId),
      existingNumbers: bookId == null
          ? const {}
          : await _dao.chapterNumbers(bookId),
    );
    if (bookId == null && plan.numbers.isEmpty) {
      throw const DriveEmptyFolderException();
    }

    final toFetch = plan.toFetch(includeAmbiguous: includeAmbiguous);
    final chapters = <ParsedChapter>[];
    var failed = 0;
    var skipped = 0;
    var done = 0;
    Object? firstError;
    onProgress?.call(0, toFetch.length);

    await _forEachLimited(toFetch, cancel, (entry) async {
      try {
        final file = await _source.fetchChapter(entry);
        cancel?.throwIfCancelled();
        final name = file.fileName;
        if (name.isNotEmpty && !isTextFileName(name)) {
          skipped++;
        } else {
          final fallback = ChapterNormalizer.stripExtension(
            name.isEmpty ? entry.title : name,
          );
          final n = ChapterNormalizer.fromBytes(file.bytes, fallback);
          chapters.add(
            ParsedChapter(
              number: plan.numbers[entry.id]!,
              title: n.title,
              content: n.content,
              driveFileId: entry.id,
              contentHash: n.hash,
              driveModified: entry.modified,
            ),
          );
        }
      } on DriveCancelledException {
        rethrow;
      } catch (e) {
        failed++;
        firstError ??= e;
      }
      done++;
      onProgress?.call(done, toFetch.length);
    });
    cancel?.throwIfCancelled();

    if (chapters.isEmpty && bookId == null) {
      final err = firstError;
      if (err is DriveException) throw err;
      if (err == null) throw const DriveEmptyFolderException();
      throw DriveException('Không tải được chương nào: $err');
    }
    if (chapters.isEmpty) {
      if (bookId != null) await _dao.touchDriveSynced(bookId, _clock());
      return DriveSyncReport(
        bookId: bookId!,
        added: 0,
        updated: 0,
        unchanged: plan.unchanged.length,
        failed: failed,
        skipped: skipped,
        isNewBook: false,
      );
    }

    chapters.sort((a, b) => a.number.compareTo(b.number));
    final result = await _dao.upsertParsed(
      ParsedBook(
        title: listing.folderName.isEmpty
            ? 'Truyện từ Google Drive'
            : listing.folderName,
        sourceType: SourceType.drive,
        driveFolderId: folderId,
        chapters: chapters,
      ),
      _clock(),
    );
    return DriveSyncReport(
      bookId: result.bookId,
      added: result.added,
      updated: result.updated,
      unchanged: result.unchanged + plan.unchanged.length,
      failed: failed,
      skipped: skipped,
      isNewBook: !result.isUpdate,
    );
  }

  static bool isTextFileName(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || lower.length - dot > 10) return true;
    return _textExtensions.contains(lower.substring(dot));
  }

  Future<void> _forEachLimited<T>(
    List<T> items,
    CancelToken? cancel,
    Future<void> Function(T item) action,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        cancel?.throwIfCancelled();
        final item = items[next++];
        await action(item);
      }
    }

    final n = concurrency.clamp(1, items.isEmpty ? 1 : items.length);
    await Future.wait([for (var i = 0; i < n; i++) worker()]);
  }
}
