import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/data_providers.dart';
import '../../domain/models/book.dart';
import '../../domain/models/reading_settings.dart';
import '../../domain/text/markdown_lite.dart';
import '../../domain/text/paragraph.dart';
import '../../services/tts_audio_handler.dart';
import '../drive/drive_provider.dart';
import '../drive/drive_ui.dart';
import '../settings/settings_provider.dart';
import '../tts/sleep_timer_sheet.dart';
import '../tts/tts_provider.dart';
import '../tts/tts_settings_sheet.dart';
import 'book_search_screen.dart';
import 'paginator.dart';
import 'reader_controls.dart';
import 'reader_settings_sheet.dart';
import 'reader_text.dart';
import 'toc_sheet.dart';

/// Đã hỏi quyền thông báo (Android 13+) lần đầu bấm "Nghe" chưa.
const String _kAskedNotifPerm = 'askedNotifPermission';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  Book? _book;
  List<ChapterInfo> _chapters = const [];
  List<Arc> _arcs = const [];
  ChapterInfo? _chapter;
  List<StoryParagraph> _paras = const [];
  Set<int> _bookmarked = <int>{};
  bool _loading = true;
  String? _error;
  bool _showBars = true;

  final ValueNotifier<int> _current = ValueNotifier<int>(0);
  bool _finishedMarked = false;
  bool _userMoved = false;
  Timer? _saveTimer;

  // Chế độ cuộn.
  ItemScrollController _scroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  // Chế độ lật trang.
  PageController? _pager;
  List<ReaderPage> _pages = const [];
  String _pagesKey = '';
  bool _programmaticPage = false;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _positions.itemPositions.addListener(_onPositions);
    ref.read(activityTrackerProvider).readerOpened(widget.bookId);
    _bootstrap();
  }

  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messenger?.hideCurrentMaterialBanner();
    _positions.itemPositions.removeListener(_onPositions);
    _saveTimer?.cancel();
    unawaited(_saveNow());
    ref.read(activityTrackerProvider).readerClosed();
    _pager?.dispose();
    _current.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_saveNow());
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(libraryRepositoryProvider);
    try {
      final book = await repo.getBook(widget.bookId);
      if (book == null) {
        setState(() {
          _loading = false;
          _error = 'Không tìm thấy truyện.';
        });
        return;
      }
      final chapters = await repo.listChapters(widget.bookId);
      final arcs = await repo.listArcs(widget.bookId);
      if (chapters.isEmpty) {
        setState(() {
          _book = book;
          _loading = false;
          _error = 'Truyện chưa có chương nào.';
        });
        return;
      }
      _book = book;
      _chapters = chapters;
      _arcs = arcs;
      final tts = ref.read(ttsHandlerProvider).state;
      int chapterId;
      var paragraph = 0;
      if (tts.active && tts.bookId == widget.bookId && tts.chapterId != null) {
        chapterId = tts.chapterId!;
        paragraph = tts.paragraph;
      } else if (book.lastChapterId != null &&
          chapters.any((c) => c.id == book.lastChapterId)) {
        chapterId = book.lastChapterId!;
        paragraph = book.lastParagraph;
      } else {
        chapterId = chapters.first.id;
      }
      await _openChapter(chapterId, paragraph);
      if (book.isDrive) unawaited(_checkDriveUpdates(book));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Lỗi mở truyện: $e';
        });
      }
    }
  }

  Future<void> _openChapter(int chapterId, int paragraph) async {
    final repo = ref.read(libraryRepositoryProvider);
    final chapter = await repo.getChapter(chapterId);
    if (chapter == null || !mounted) return;
    final paras = MarkdownLite.parseChapter(chapter.title, chapter.content);
    final marks = (await repo.bookmarks(widget.bookId))
        .where((b) => b.chapterId == chapterId)
        .map((b) => b.paragraph)
        .toSet();
    if (!mounted) return;
    final p = paragraph.clamp(0, paras.length - 1);
    setState(() {
      _chapter = chapter.info;
      _paras = paras;
      _bookmarked = marks;
      _finishedMarked = chapter.info.finished;
      _loading = false;
      _error = null;
      _userMoved = false;
      _scroll = ItemScrollController();
      _pagesKey = '';
    });
    _current.value = p;
    _scheduleSave();
  }

  // ───────────────────────── vị trí & lưu ─────────────────────────

  void _onPositions() {
    if (ref.read(settingsProvider).pageMode) return;
    final positions = _positions.itemPositions.value.where(
      (p) => p.itemTrailingEdge > 0.02,
    );
    if (positions.isEmpty || _paras.isEmpty) return;
    final first = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final idx = first.clamp(0, _paras.length - 1);
    if (idx != _current.value) {
      _current.value = idx;
      _scheduleSave();
    }
    final lastVisible = _positions.itemPositions.value.any(
      (p) => p.index >= _paras.length - 1 && p.itemTrailingEdge <= 1.0,
    );
    if (lastVisible) _markFinished();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () => unawaited(_saveNow()));
  }

  bool get _ttsOwnsPosition {
    final s = ref.read(ttsHandlerProvider).state;
    return s.playing && s.bookId == widget.bookId;
  }

  Future<void> _saveNow() async {
    final chapter = _chapter;
    if (chapter == null || _paras.isEmpty || _ttsOwnsPosition) return;
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveProgress(
            bookId: widget.bookId,
            chapterId: chapter.id,
            paragraph: _current.value,
            fraction: _current.value / _paras.length,
          );
    } catch (_) {
      // DB có thể đã đóng khi thoát app; bỏ qua.
    }
  }

  void _markFinished() {
    final chapter = _chapter;
    if (_finishedMarked || chapter == null) return;
    _finishedMarked = true;
    unawaited(
      ref.read(libraryRepositoryProvider).markChapterFinished(chapter.id),
    );
  }

  // ───────────────────────── điều hướng ─────────────────────────

  int get _chapterIndex => _chapters.indexWhere((c) => c.id == _chapter?.id);

  bool get _hasPrevious => _chapterIndex > 0;
  bool get _hasNext =>
      _chapterIndex >= 0 && _chapterIndex < _chapters.length - 1;

  bool get _ttsActiveHere {
    final s = ref.read(ttsHandlerProvider).state;
    return s.active && s.bookId == widget.bookId;
  }

  Future<void> _step({required bool forward}) async {
    if (_ttsActiveHere) {
      final h = ref.read(ttsHandlerProvider);
      await (forward ? h.skipToNext() : h.skipToPrevious());
      return;
    }
    final i = _chapterIndex + (forward ? 1 : -1);
    if (i < 0 || i >= _chapters.length) return;
    await _saveNow();
    await _openChapter(_chapters[i].id, 0);
    unawaited(_refreshChapterList());
  }

  /// Kiểm tra nền xem thư mục Drive có chương mới không (tối đa 10 phút/lần).
  Future<void> _checkDriveUpdates(Book book) async {
    final check = await ref.read(driveUpdatesProvider.notifier).check(book);
    final messenger = _messenger;
    if (!mounted || check == null || !check.hasUpdates || messenger == null) {
      return;
    }
    DriveUi.showUpdateAvailable(
      messenger,
      check,
      onUpdate: () => unawaited(_syncDrive()),
    );
  }

  Future<void> _syncDrive() async {
    final book = _book;
    if (book == null) return;
    final report = await DriveUi.syncNow(context, ref, book);
    if (report != null && mounted) await _refreshChapterList();
  }

  Future<void> _refreshChapterList() async {
    final list = await ref
        .read(libraryRepositoryProvider)
        .listChapters(widget.bookId);
    if (mounted) setState(() => _chapters = list);
  }

  Future<void> _jump(JumpTarget target) async {
    if (target.chapterId == _chapter?.id) {
      _goToParagraph(target.paragraph);
    } else {
      if (_ttsActiveHere) {
        await ref
            .read(ttsHandlerProvider)
            .startFrom(
              bookId: widget.bookId,
              chapterId: target.chapterId,
              paragraph: target.paragraph,
              autoPlay: ref.read(ttsHandlerProvider).state.playing,
            );
      } else {
        await _openChapter(target.chapterId, target.paragraph);
      }
    }
  }

  /// Vị trí (theo tỉ lệ khung nhìn) đặt đoạn khi nhảy tới, để không nằm dưới
  /// thanh tiêu đề đang phủ phía trên. Đoạn 0 (tiêu đề chương) đã có đệm đầu
  /// danh sách nên để 0.
  double _readAlignment(int index) {
    if (index <= 0) return 0;
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return ((top + kToolbarHeight + 8) / size.height).clamp(0.0, 0.4);
  }

  void _goToParagraph(int paragraph, {bool animate = false}) {
    final p = paragraph.clamp(0, _paras.length - 1);
    _current.value = p;
    if (ref.read(settingsProvider).pageMode) {
      final c = _pager;
      if (c != null && c.hasClients && _pages.isNotEmpty) {
        _programmaticPage = true;
        final target = Paginator.pageOfParagraph(_pages, p);
        if (animate) {
          c
              .animateToPage(
                target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              )
              .whenComplete(() => _programmaticPage = false);
        } else {
          c.jumpToPage(target);
          _programmaticPage = false;
        }
      }
    } else if (_scroll.isAttached) {
      if (animate) {
        unawaited(
          _scroll.scrollTo(
            index: p,
            alignment: _readAlignment(p),
            duration: const Duration(milliseconds: 250),
          ),
        );
      } else {
        _scroll.jumpTo(index: p);
      }
    }
    _scheduleSave();
  }

  // ───────────────────────── TTS ─────────────────────────

  /// Theo dõi câu đang đọc. Chạy mỗi khi đổi CÂU (không chỉ đổi đoạn): người
  /// dùng tự lật/cuộn trong lúc nghe thì được tôn trọng cho tới câu kế tiếp,
  /// rồi màn hình tự quay lại đúng chỗ đang đọc (cả chế độ cuộn lẫn lật trang).
  void _followTts(TtsUiState s) {
    final p = s.paragraph;
    if (ref.read(settingsProvider).pageMode) {
      final c = _pager;
      if (c == null || !c.hasClients || _pages.isEmpty) return;
      // Câu có thể vắt qua nhiều trang: đang ở một trong các trang đó thì giữ
      // nguyên, ngược lại lật tới trang nơi câu BẮT ĐẦU.
      final span = Paginator.pagesOfRange(
        _pages,
        p,
        s.sentenceStart,
        s.sentenceEnd,
      );
      final target = span.isNotEmpty
          ? span.first
          : Paginator.pageOfParagraph(_pages, p);
      if (!span.contains(_pageIndex) && target != _pageIndex) {
        _programmaticPage = true;
        c
            .animateToPage(
              target,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            )
            .whenComplete(() => _programmaticPage = false);
      }
      _current.value = p;
      return;
    }
    if (!_scroll.isAttached) return;
    final pos = _positions.itemPositions.value.where((e) => e.index == p);
    final visible =
        pos.isNotEmpty &&
        pos.first.itemLeadingEdge >= 0 &&
        pos.first.itemTrailingEdge <= 0.85;
    if (!visible) {
      unawaited(
        _scroll.scrollTo(
          index: p,
          alignment: _readAlignment(p),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
    _current.value = p;
  }

  /// Lần đầu bấm nghe (Android 13+): xin quyền thông báo và CHỜ kết quả trước
  /// khi phát, để hộp thoại không hiện chồng lên lúc đang đọc. Chỉ hỏi một lần.
  Future<void> _ensureNotificationPermission() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_kAskedNotifPerm) ?? false) return;
    await prefs.setBool(_kAskedNotifPerm, true);
    await ref.read(systemChannelProvider).requestNotificationPermission();
  }

  Future<void> _togglePlay() async {
    final h = ref.read(ttsHandlerProvider);
    final chapter = _chapter;
    if (chapter == null) return;
    final st = h.state;
    if (st.playing && st.bookId == widget.bookId) {
      await h.pause();
      return;
    }
    await _ensureNotificationPermission();
    if (!mounted) return;
    final s = ref.read(settingsProvider);
    h.configure(
      speed: s.ttsSpeed,
      pitch: s.ttsPitch,
      voiceName: s.ttsVoiceName,
      voiceLocale: s.ttsVoiceLocale,
      engine: s.ttsEngine,
    );
    if (st.active && st.bookId == widget.bookId && st.chapterId == chapter.id) {
      if (_userMoved) {
        await h.seekToParagraph(_current.value);
        _userMoved = false;
      }
      await h.play();
      return;
    }
    await h.startFrom(
      bookId: widget.bookId,
      chapterId: chapter.id,
      paragraph: _current.value,
    );
  }

  /// Engine TTS lỗi liên tiếp: đã dừng đúng câu đang đọc (không bỏ qua câu nào).
  void _showSpeakFailedBanner() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: const Text(
          'Không đọc được: giọng tiếng Việt chưa sẵn sàng (có thể đang tải). '
          'Thử lại sau hoặc mở cài đặt TTS.',
        ),
        leading: const Icon(Icons.error_outline),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(ref.read(systemChannelProvider).openTtsSettings());
            },
            child: const Text('Cài đặt TTS'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              unawaited(ref.read(ttsHandlerProvider).play());
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Future<void> _longPressParagraph(int index) async {
    final p = _paras[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.headphones),
              title: const Text('Đọc từ đây'),
              onTap: () => Navigator.pop(ctx, 'tts'),
            ),
            ListTile(
              leading: Icon(
                _bookmarked.contains(index)
                    ? Icons.bookmark_remove
                    : Icons.bookmark_add,
              ),
              title: Text(
                _bookmarked.contains(index) ? 'Bỏ dấu trang' : 'Đặt dấu trang',
              ),
              onTap: () => Navigator.pop(ctx, 'bookmark'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || p.text.isEmpty) return;
    if (action == 'bookmark') {
      await _toggleBookmark(index);
    } else if (action == 'tts') {
      await _ensureNotificationPermission();
      if (!mounted) return;
      _current.value = index;
      _userMoved = false;
      final h = ref.read(ttsHandlerProvider);
      if (_ttsActiveHere && h.state.chapterId == _chapter?.id) {
        await h.seekToParagraph(index);
        await h.play();
      } else {
        await h.startFrom(
          bookId: widget.bookId,
          chapterId: _chapter!.id,
          paragraph: index,
        );
      }
    }
  }

  Future<void> _toggleBookmark([int? at]) async {
    final chapter = _chapter;
    if (chapter == null || _paras.isEmpty) return;
    final idx = at ?? _current.value;
    final text = _paras[idx].text;
    final snippet = text.length > 90 ? '${text.substring(0, 90)}…' : text;
    final added = await ref
        .read(libraryRepositoryProvider)
        .toggleBookmark(
          bookId: widget.bookId,
          chapterId: chapter.id,
          paragraph: idx,
          snippet: snippet.isEmpty ? chapter.title : snippet,
        );
    if (!mounted) return;
    setState(() {
      _bookmarked = {..._bookmarked};
      if (added) {
        _bookmarked.add(idx);
      } else {
        _bookmarked.remove(idx);
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(added ? 'Đã thêm dấu trang' : 'Đã bỏ dấu trang'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final palette = ReaderPalette.of(settings.theme);
    final ttsAsync = ref.watch(ttsStateProvider);

    ref.listen<ReadingSettings>(settingsProvider, (prev, next) {
      unawaited(WakelockPlus.toggle(enable: next.keepScreenOn));
    });
    ref.listen<AsyncValue<TtsUiState>>(ttsStateProvider, (prev, next) {
      final s = next.value;
      if (s == null || s.bookId != widget.bookId || !s.active) return;
      if (s.chapterId != _chapter?.id) {
        unawaited(
          _openChapter(
            s.chapterId!,
            s.paragraph,
          ).then((_) => _refreshChapterList()),
        );
        return;
      }
      final p = prev?.value;
      if (p == null ||
          p.paragraph != s.paragraph ||
          p.sentenceStart != s.sentenceStart ||
          p.playing != s.playing) {
        _followTts(s);
        if (s.playing) _userMoved = false;
      }
      if (s.problem == TtsProblem.speakFailed &&
          p?.problem != TtsProblem.speakFailed) {
        _showSpeakFailedBanner();
      } else if (s.problem != TtsProblem.speakFailed &&
          p?.problem == TtsProblem.speakFailed) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
      if (s.problem == TtsProblem.noVietnameseVoice &&
          p?.problem != TtsProblem.noVietnameseVoice) {
        unawaited(showNoVoiceDialog(context, ref));
      } else if (s.problem == TtsProblem.engineError &&
          p?.problem != TtsProblem.engineError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Engine TTS gặp lỗi liên tục nên đã dừng. Thử đổi bộ máy/giọng đọc.',
            ),
          ),
        );
      }
    });
    unawaited(WakelockPlus.toggle(enable: settings.keepScreenOn));

    final tts = ttsAsync.value;
    final ttsHere = (tts != null && tts.bookId == widget.bookId && tts.active)
        ? tts
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: _body(settings, palette, ttsHere),
    );
  }

  ReaderStyles _styles(ReadingSettings s, ReaderPalette pal) =>
      ReaderStyles.forReader(
        fontFamily: s.font.family,
        fontSize: s.fontSize,
        lineHeight: s.lineHeight,
        textColor: pal.text,
        sentenceHighlight: pal.sentenceHighlight,
      );

  Widget _body(ReadingSettings settings, ReaderPalette pal, TtsUiState? tts) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: pal.text),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final styles = _styles(settings, pal);
    final top = MediaQuery.paddingOf(context).top;
    final barsVisible = _showBars;

    final content = Listener(
      onPointerDown: (_) => ref.read(activityTrackerProvider).interaction(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          ref.read(activityTrackerProvider).interaction();
          if (n is UserScrollNotification &&
              n.direction != ScrollDirection.idle) {
            _userMoved = true;
          }
          return false;
        },
        child: settings.pageMode
            ? _pageMode(settings, pal, styles, tts)
            : _scrollMode(settings, pal, styles, tts),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !barsVisible,
            child: AnimatedOpacity(
              opacity: barsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: SizedBox(
                height: kToolbarHeight + top,
                child: _appBar(pal),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !(barsVisible || tts != null),
            child: AnimatedOpacity(
              opacity: (barsVisible || tts != null) ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: ReaderBottomBar(
                tts: tts,
                color: pal.background,
                textColor: pal.text,
                hasPrevious: _hasPrevious,
                hasNext: _hasNext,
                onPreviousChapter: () => _step(forward: false),
                onNextChapter: () => _step(forward: true),
                onPlayPause: _togglePlay,
                onPreviousSentence: () =>
                    ref.read(ttsHandlerProvider).previousSentence(),
                onNextSentence: () =>
                    ref.read(ttsHandlerProvider).nextSentence(),
                onStop: () => ref.read(ttsHandlerProvider).stop(),
                onSpeedChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .update(ref.read(settingsProvider).copyWith(ttsSpeed: v));
                  unawaited(ref.read(ttsHandlerProvider).changeSpeed(v));
                },
                onSleepTimer: () => showSleepTimerSheet(context),
                onVoiceSettings: () => showTtsSettingsSheet(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appBar(ReaderPalette pal) {
    return AppBar(
      backgroundColor: pal.background,
      foregroundColor: pal.text,
      elevation: 2,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _book?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            _chapter?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: pal.muted),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: _current,
          builder: (_, cur, _) => IconButton(
            tooltip: 'Dấu trang',
            icon: Icon(
              _bookmarked.contains(cur)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: _toggleBookmark,
          ),
        ),
        IconButton(
          tooltip: 'Tìm trong truyện',
          icon: const Icon(Icons.search),
          onPressed: () async {
            final t = await Navigator.of(context).push<JumpTarget>(
              MaterialPageRoute(
                builder: (_) => BookSearchScreen(bookId: widget.bookId),
              ),
            );
            if (t != null) await _jump(t);
          },
        ),
        IconButton(
          tooltip: 'Mục lục',
          icon: const Icon(Icons.list),
          onPressed: () async {
            final book = _book;
            final chapter = _chapter;
            if (book == null || chapter == null) return;
            final t = await showTocSheet(
              context,
              book: book,
              chapters: _chapters,
              arcs: _arcs,
              currentChapterId: chapter.id,
            );
            if (t != null) await _jump(t);
          },
        ),
        IconButton(
          tooltip: 'Giao diện',
          icon: const Icon(Icons.text_fields),
          onPressed: () => showReaderSettingsSheet(context),
        ),
        if (_book?.isDrive ?? false)
          PopupMenuButton<String>(
            tooltip: 'Thêm',
            onSelected: (_) => unawaited(_syncDrive()),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'drive', child: Text('Cập nhật từ Drive')),
            ],
          ),
      ],
    );
  }

  // ───────────────────────── chế độ cuộn ─────────────────────────

  Widget _scrollMode(
    ReadingSettings s,
    ReaderPalette pal,
    ReaderStyles styles,
    TtsUiState? tts,
  ) {
    final top = MediaQuery.paddingOf(context).top;
    final spacing = s.fontSize * 0.6;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _showBars = !_showBars),
      child: ScrollablePositionedList.builder(
        key: ValueKey('scroll-${_chapter?.id}'),
        itemScrollController: _scroll,
        itemPositionsListener: _positions,
        initialScrollIndex: _current.value.clamp(0, _paras.length - 1),
        initialAlignment: _readAlignment(_current.value),
        padding: EdgeInsets.only(top: top + kToolbarHeight + 12, bottom: 200),
        itemCount: _paras.length + 1,
        itemBuilder: (context, i) {
          if (i == _paras.length) return _chapterFooter(pal);
          final p = _paras[i];
          final reading =
              tts != null &&
              tts.chapterId == _chapter?.id &&
              tts.paragraph == i;
          return GestureDetector(
            onLongPress: p.kind == ParagraphKind.separator
                ? null
                : () => _longPressParagraph(i),
            child: Container(
              color: reading ? pal.highlight : null,
              padding: EdgeInsets.fromLTRB(
                s.margin,
                spacing / 2,
                s.margin,
                spacing / 2,
              ),
              child: _paragraphContent(
                p,
                styles,
                pal,
                hlStart: reading ? tts.sentenceStart : null,
                hlEnd: reading ? tts.sentenceEnd : null,
                bookmarked: _bookmarked.contains(i),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paragraphContent(
    StoryParagraph p,
    ReaderStyles styles,
    ReaderPalette pal, {
    int? hlStart,
    int? hlEnd,
    bool bookmarked = false,
  }) {
    if (p.kind == ParagraphKind.separator) {
      return Center(
        child: Text(
          '* * *',
          style: TextStyle(color: pal.muted, letterSpacing: 4),
        ),
      );
    }
    final text = Text.rich(
      buildParagraphSpan(p, styles, hlStart: hlStart, hlEnd: hlEnd),
      textAlign: p.kind == ParagraphKind.heading
          ? TextAlign.center
          : TextAlign.start,
      textScaler: TextScaler.noScaling,
      locale: kReaderLocale,
    );
    if (!bookmarked) return text;
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(right: 14), child: text),
        Positioned(
          right: 0,
          top: 2,
          child: Icon(Icons.bookmark, size: 16, color: pal.muted),
        ),
      ],
    );
  }

  Widget _chapterFooter(ReaderPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Text('— Hết chương —', style: TextStyle(color: pal.muted)),
          const SizedBox(height: 12),
          if (_hasNext)
            FilledButton.icon(
              onPressed: () => _step(forward: true),
              icon: const Icon(Icons.skip_next),
              label: const Text('Chương tiếp theo'),
            )
          else
            Text('Đã đến chương mới nhất.', style: TextStyle(color: pal.muted)),
        ],
      ),
    );
  }

  // ───────────────────────── chế độ lật trang ─────────────────────────

  Widget _pageMode(
    ReadingSettings s,
    ReaderPalette pal,
    ReaderStyles styles,
    TtsUiState? tts,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final safe = MediaQuery.paddingOf(context);
        // Vùng chữ nằm giữa thanh tiêu đề và thanh điều khiển (cả hai phủ lên
        // nội dung). Dùng CÙNG các lề này để đo trang và để vẽ trang.
        final topInset = safe.top + kToolbarHeight + 8;
        final bottomInset = safe.bottom + ReaderBottomBar.maxContentHeight + 8;
        final width = box.maxWidth - s.margin * 2;
        final height = box.maxHeight - topInset - bottomInset;
        final spacing = s.fontSize * 0.6;
        final key =
            '${_chapter?.id}|${width.round()}|${height.round()}|${s.fontSize}|${s.lineHeight}|${s.font.name}';
        if (key != _pagesKey) {
          _pagesKey = key;
          _pages = Paginator.paginate(
            _paras,
            styles,
            width: width,
            height: height,
            paragraphSpacing: spacing,
          );
          final start = Paginator.pageOfParagraph(_pages, _current.value);
          _pager?.dispose();
          _pager = PageController(initialPage: start);
          _pageIndex = start;
        }
        final pages = _pages;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final x = d.localPosition.dx / box.maxWidth;
            final c = _pager!;
            if (x < 0.3) {
              unawaited(
                c.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              );
            } else if (x > 0.7) {
              unawaited(
                c.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              );
            } else {
              setState(() => _showBars = !_showBars);
            }
          },
          child: PageView.builder(
            controller: _pager,
            itemCount: pages.length + 1,
            onPageChanged: (i) {
              _pageIndex = i;
              if (!_programmaticPage) _userMoved = true;
              if (i >= pages.length) {
                _markFinished();
                return;
              }
              _current.value = pages[i].firstParagraph;
              if (i == pages.length - 1) _markFinished();
              _scheduleSave();
            },
            itemBuilder: (context, i) {
              if (i >= pages.length) return Center(child: _chapterFooter(pal));
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  s.margin,
                  topInset,
                  s.margin,
                  bottomInset,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final sl in pages[i].slices)
                          _sliceWidget(sl, styles, pal, spacing, tts),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sliceWidget(
    PageSlice sl,
    ReaderStyles styles,
    ReaderPalette pal,
    double spacing,
    TtsUiState? tts,
  ) {
    final p = _paras[sl.paragraph];
    if (p.kind == ParagraphKind.separator) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            '* * *',
            style: TextStyle(color: pal.muted, letterSpacing: 4),
          ),
        ),
      );
    }
    final reading =
        tts != null &&
        tts.chapterId == _chapter?.id &&
        tts.paragraph == sl.paragraph;
    return Padding(
      padding: EdgeInsets.only(bottom: sl.end >= p.text.length ? spacing : 0),
      child: SizedBox(
        width: double.infinity,
        child: Text.rich(
          buildParagraphSpan(
            p,
            styles,
            from: sl.start,
            to: sl.end,
            hlStart: reading ? tts.sentenceStart : null,
            hlEnd: reading ? tts.sentenceEnd : null,
          ),
          textAlign: p.kind == ParagraphKind.heading
              ? TextAlign.center
              : TextAlign.start,
          textScaler: TextScaler.noScaling,
          locale: kReaderLocale,
        ),
      ),
    );
  }
}
