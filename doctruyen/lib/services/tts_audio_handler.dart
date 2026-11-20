import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/repositories/library_repository.dart';
import '../domain/models/book.dart';
import '../domain/stats/activity_accumulator.dart';
import '../domain/text/markdown_lite.dart';
import '../domain/text/paragraph.dart';
import '../domain/text/sentence_splitter.dart';
import '../domain/tts/sleep_timer.dart';
import '../domain/tts/speak_retry.dart';

enum TtsProblem { none, noVietnameseVoice, engineError, speakFailed }

/// Giọng đọc khả dụng trên máy.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;
  final String locale;
}

/// Trạng thái TTS cho UI.
class TtsUiState {
  const TtsUiState({
    this.bookId,
    this.chapterId,
    this.chapterTitle = '',
    this.bookTitle = '',
    this.paragraph = 0,
    this.sentenceStart = 0,
    this.sentenceEnd = 0,
    this.playing = false,
    this.loading = false,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.problem = TtsProblem.none,
    this.sleepMode = SleepTimerMode.off,
    this.sleepRemaining,
  });

  final int? bookId;
  final int? chapterId;
  final String chapterTitle;
  final String bookTitle;

  /// Chỉ số đoạn đang đọc (0 là tiêu đề chương).
  final int paragraph;
  final int sentenceStart;
  final int sentenceEnd;
  final bool playing;
  final bool loading;
  final double speed;
  final double pitch;
  final TtsProblem problem;
  final SleepTimerMode sleepMode;
  final Duration? sleepRemaining;

  /// Có một phiên đọc được nạp (đang phát hoặc tạm dừng).
  bool get active => chapterId != null;

  TtsUiState copyWith({
    int? bookId,
    int? chapterId,
    String? chapterTitle,
    String? bookTitle,
    int? paragraph,
    int? sentenceStart,
    int? sentenceEnd,
    bool? playing,
    bool? loading,
    double? speed,
    double? pitch,
    TtsProblem? problem,
    SleepTimerMode? sleepMode,
    Duration? sleepRemaining,
    bool clearSleepRemaining = false,
  }) => TtsUiState(
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    bookTitle: bookTitle ?? this.bookTitle,
    paragraph: paragraph ?? this.paragraph,
    sentenceStart: sentenceStart ?? this.sentenceStart,
    sentenceEnd: sentenceEnd ?? this.sentenceEnd,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    speed: speed ?? this.speed,
    pitch: pitch ?? this.pitch,
    problem: problem ?? this.problem,
    sleepMode: sleepMode ?? this.sleepMode,
    sleepRemaining: clearSleepRemaining
        ? null
        : (sleepRemaining ?? this.sleepRemaining),
  );
}

class _Unit {
  const _Unit(this.paragraph, this.start, this.end, this.text);

  final int paragraph;
  final int start;
  final int end;
  final String text;
}

/// Đọc truyện bằng flutter_tts, chạy nền qua audio_service (thông báo media +
/// màn hình khóa). Đọc từng câu; tự sang chương kế; hẹn giờ tắt; tự lưu vị trí.
///
/// Chạy trong isolate chính (mặc định của `AudioService.init`) nên truy cập
/// thẳng repository/DB được.
class StoryAudioHandler extends BaseAudioHandler {
  StoryAudioHandler({
    required this._library,
    required this._activity,
    FlutterTts? tts,
    DateTime Function()? clock,
    this._onKeepAwake,
  }) : _tts = tts ?? FlutterTts(),
       _clock = clock ?? DateTime.now;

  final LibraryRepository _library;
  final ActivityAccumulator _activity;
  final FlutterTts _tts;
  final DateTime Function() _clock;

  /// Giữ CPU thức khi đang đọc (tắt màn hình giữa hai câu không bị ngủ).
  final void Function(bool keepAwake)? _onKeepAwake;
  bool _awake = false;

  void _setKeepAwake(bool v) {
    if (_awake == v) return;
    _awake = v;
    _onKeepAwake?.call(v);
  }

  final StreamController<TtsUiState> _ui =
      StreamController<TtsUiState>.broadcast();
  TtsUiState _state = const TtsUiState();

  final SleepTimer _sleep = SleepTimer();
  Timer? _sleepTicker;

  List<StoryParagraph> _paragraphs = const [];
  List<_Unit> _units = const [];
  int _unitIdx = 0;
  int _gen = 0;
  bool _playing = false;
  Completer<void>? _utterance;
  final SpeakRetryPolicy _retry = SpeakRetryPolicy();
  bool _utteranceFailed = false;
  bool _initialized = false;
  bool _resumeAfterInterruption = false;
  bool _configDirty = true;

  double _speed = 1.0;
  double _pitch = 1.0;
  String? _voiceName;
  String? _voiceLocale;
  String? _engine;

  TtsUiState get state => _state;
  Stream<TtsUiState> get uiStream => _ui.stream;
  List<StoryParagraph> get paragraphs => _paragraphs;

  void _emit(TtsUiState s) {
    _state = s;
    if (!_ui.isClosed) _ui.add(s);
  }

  // ─────────────────────────── khởi tạo ───────────────────────────

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    _tts.setCompletionHandler(() => _finishUtterance());
    _tts.setErrorHandler((dynamic msg) {
      debugPrint('TTS error: $msg');
      // Bỏ qua lỗi của câu đã bị huỷ (đổi câu/dừng) để không tính nhầm.
      if (_utterance == null) return;
      _utteranceFailed = true;
      _finishUtterance();
    });
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    session.interruptionEventStream.listen(_onInterruption);
    session.becomingNoisyEventStream.listen((_) {
      if (_playing) unawaited(pause());
    });
  }

  void _onInterruption(AudioInterruptionEvent e) {
    if (e.begin) {
      if (e.type == AudioInterruptionType.duck) {
        unawaited(_tts.setVolume(0.3));
      } else if (_playing) {
        _resumeAfterInterruption = true;
        unawaited(pause());
      }
    } else {
      if (e.type == AudioInterruptionType.duck) {
        unawaited(_tts.setVolume(_sleep.volumeFactor(_clock())));
      } else if (_resumeAfterInterruption) {
        _resumeAfterInterruption = false;
        if (e.type == AudioInterruptionType.pause) unawaited(play());
      }
    }
  }

  // ─────────────────────────── cấu hình ───────────────────────────

  /// Áp cài đặt giọng đọc (gọi khi người dùng đổi hoặc lúc mở app).
  void configure({
    double? speed,
    double? pitch,
    String? voiceName,
    String? voiceLocale,
    String? engine,
  }) {
    if (speed != null) _speed = speed.clamp(0.5, 2.0);
    if (pitch != null) _pitch = pitch.clamp(0.5, 2.0);
    if (voiceName != null) {
      _voiceName = voiceName;
      _voiceLocale = voiceLocale;
    }
    if (engine != null) _engine = engine;
    _configDirty = true;
    _emit(_state.copyWith(speed: _speed, pitch: _pitch));
  }

  Future<bool> _applyConfig() async {
    await _init();
    if (!_configDirty) return true;
    final engine = _engine;
    if (engine != null && engine.isNotEmpty) {
      await _tts.setEngine(engine);
    }
    final lang = await _tts.setLanguage('vi-VN');
    final ok = lang == 1 || lang == true;
    if (!ok) {
      _emit(_state.copyWith(problem: TtsProblem.noVietnameseVoice));
      return false;
    }
    final vn = _voiceName;
    if (vn != null) {
      await _tts.setVoice({'name': vn, 'locale': _voiceLocale ?? 'vi-VN'});
    }
    // flutter_tts trên Android nhân đôi giá trị: 0.5 ≈ tốc độ bình thường.
    await _tts.setSpeechRate(_speed / 2);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(1.0);
    _configDirty = false;
    if (_state.problem != TtsProblem.none) {
      _emit(_state.copyWith(problem: TtsProblem.none));
    }
    return true;
  }

  Future<List<TtsVoice>> vietnameseVoices() async {
    await _init();
    final raw = await _tts.getVoices;
    final out = <TtsVoice>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          if (name.isNotEmpty &&
              locale.toLowerCase().replaceAll('_', '-').startsWith('vi')) {
            out.add(TtsVoice(name: name, locale: locale));
          }
        }
      }
    }
    return out;
  }

  Future<List<String>> engines() async {
    await _init();
    final raw = await _tts.getEngines;
    return raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
  }

  /// `true` nếu máy có giọng tiếng Việt dùng được.
  Future<bool> hasVietnamese() async {
    await _init();
    final r = await _tts.isLanguageAvailable('vi-VN');
    if (r == true || r == 1) return true;
    return (await vietnameseVoices()).isNotEmpty;
  }

  // ─────────────────────────── nạp chương ───────────────────────────

  /// Nạp chương và bắt đầu đọc từ đoạn [paragraph].
  Future<void> startFrom({
    required int bookId,
    required int chapterId,
    int paragraph = 0,
    bool autoPlay = true,
  }) async {
    _bump();
    _emit(_state.copyWith(loading: true, bookId: bookId));
    final book = await _library.getBook(bookId);
    final ok = await _loadChapter(chapterId, paragraph, book);
    if (!ok) {
      _emit(_state.copyWith(loading: false));
      return;
    }
    if (autoPlay) await play();
  }

  Future<bool> _loadChapter(int chapterId, int paragraph, Book? book) async {
    final chapter = await _library.getChapter(chapterId);
    if (chapter == null) return false;
    _paragraphs = MarkdownLite.parseChapter(chapter.title, chapter.content);
    _units = _buildUnits(_paragraphs);
    _unitIdx = _units.indexWhere((u) => u.paragraph >= paragraph);
    if (_unitIdx < 0) _unitIdx = _units.isEmpty ? 0 : _units.length - 1;
    final bookTitle = book?.displayTitle ?? _state.bookTitle;
    _emit(
      _state.copyWith(
        bookId: chapter.info.bookId,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        bookTitle: bookTitle,
        loading: false,
      ),
    );
    _publishPosition();
    mediaItem.add(
      MediaItem(
        id: 'chapter-${chapter.id}',
        title: chapter.title,
        album: bookTitle,
        artist: 'Đọc Truyện',
      ),
    );
    _broadcast();
    return true;
  }

  static List<_Unit> _buildUnits(List<StoryParagraph> paragraphs) {
    final units = <_Unit>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (!p.isReadable) continue;
      for (final s in SentenceSplitter.split(p.text)) {
        final speak = SentenceSplitter.speakable(s.slice(p.text));
        if (speak.isEmpty) continue;
        units.add(_Unit(i, s.start, s.end, speak));
      }
    }
    return units;
  }

  void _publishPosition() {
    if (_units.isEmpty) {
      _emit(_state.copyWith(paragraph: 0, sentenceStart: 0, sentenceEnd: 0));
      return;
    }
    final u = _units[_unitIdx.clamp(0, _units.length - 1)];
    _emit(
      _state.copyWith(
        paragraph: u.paragraph,
        sentenceStart: u.start,
        sentenceEnd: u.end,
      ),
    );
  }

  // ─────────────────────────── phát ───────────────────────────

  void _bump() {
    _gen++;
    _retry.reset();
    _cancelUtterance();
  }

  void _cancelUtterance() {
    final c = _utterance;
    _utterance = null;
    if (c != null && !c.isCompleted) c.complete();
    unawaited(_tts.stop());
  }

  void _finishUtterance() {
    final c = _utterance;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> play() async {
    if (_state.chapterId == null) return;
    if (_playing) return;
    if (!await _applyConfig()) {
      _playing = false;
      _broadcast();
      return;
    }
    final session = await AudioSession.instance;
    if (!await session.setActive(true)) {
      debugPrint('Không giành được audio focus');
    }
    _playing = true;
    _setKeepAwake(true);
    _activity.setListening(_state.bookId);
    _emit(_state.copyWith(playing: true, problem: TtsProblem.none));
    _broadcast();
    unawaited(_loop(++_gen));
  }

  @override
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    _setKeepAwake(false);
    _activity.setListening(null);
    _bump();
    _emit(_state.copyWith(playing: false));
    _broadcast();
    unawaited(_saveProgress());
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _setKeepAwake(false);
    _activity.setListening(null);
    _bump();
    _cancelSleep();
    final session = await AudioSession.instance;
    await session.setActive(false);
    await _saveProgress();
    _emit(const TtsUiState().copyWith(speed: _speed, pitch: _pitch));
    _paragraphs = const [];
    _units = const [];
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
    await super.stop();
  }

  Future<void> _loop(int gen) async {
    while (gen == _gen && _playing) {
      if (_unitIdx >= _units.length) {
        final cont = await _onChapterEnd(gen);
        if (!cont) return;
        continue;
      }
      final u = _units[_unitIdx];
      final before = _state.paragraph;
      // Gửi lệnh đọc TRƯỚC: câu kế phải vào hàng đợi engine ngay khi câu trước
      // xong, không chờ cập nhật UI/DB (nền có thể bị làm chậm).
      final spoken = _speak(u.text, gen);
      _publishPosition();
      if (u.paragraph != before || _unitIdx == 0) unawaited(_saveProgress());
      final ok = await spoken;
      if (gen != _gen) return;
      if (ok) {
        _retry.onSuccess();
        _unitIdx++;
        continue;
      }
      // Lỗi: tuyệt đối không sang câu kế khi câu này chưa được đọc.
      switch (_retry.onFailure()) {
        case SpeakFailureAction.retry:
          await Future<void>.delayed(_retry.retryDelay);
          // Đã dừng/chuyển câu trong lúc chờ thì thôi (vòng lặp mới lo).
          if (gen != _gen || !_playing) return;
        case SpeakFailureAction.giveUp:
          _playing = false;
          _configDirty = true; // lần thử lại sẽ kiểm tra lại ngôn ngữ/giọng
          _activity.setListening(null);
          _bump();
          _emit(
            _state.copyWith(playing: false, problem: TtsProblem.speakFailed),
          );
          _broadcast();
          _setKeepAwake(false);
          unawaited(_saveProgress());
          return;
      }
    }
  }

  /// Đọc một câu. `true` = đọc xong bình thường; `false` = engine lỗi hoặc
  /// treo (câu chưa được đọc).
  Future<bool> _speak(String text, int gen) async {
    final c = Completer<void>();
    _utterance = c;
    _utteranceFailed = false;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('speak lỗi: $e');
      return false;
    }
    // Chốt an toàn nếu engine không bao giờ báo hoàn thành.
    var timedOut = false;
    final timeoutSeconds = 30 + (text.length * 0.4 / _speed).ceil();
    await c.future.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        debugPrint('TTS hết thời gian chờ câu');
        timedOut = true;
        unawaited(_tts.stop());
      },
    );
    if (gen != _gen) return true;
    return !_utteranceFailed && !timedOut;
  }

  /// Hết chương. Trả `true` nếu vòng lặp nên tiếp tục (đã sang chương mới).
  Future<bool> _onChapterEnd(int gen) async {
    final chapterId = _state.chapterId;
    final bookId = _state.bookId;
    if (chapterId == null || bookId == null) return false;
    await _library.markChapterFinished(chapterId);
    final next = await _library.nextChapter(chapterId);
    if (gen != _gen) return false;
    final stopAfter = _sleep.onChapterFinished();
    _refreshSleepState();
    if (next == null) {
      await _library.saveProgress(
        bookId: bookId,
        chapterId: chapterId,
        paragraph: _paragraphs.length,
        fraction: 1,
      );
      _playing = false;
      _activity.setListening(null);
      _setKeepAwake(false);
      _emit(_state.copyWith(playing: false));
      _broadcast();
      return false;
    }
    final loaded = await _loadChapter(next.id, 0, null);
    if (!loaded || gen != _gen) return false;
    unawaited(_saveProgress());
    if (stopAfter) {
      _playing = false;
      _setKeepAwake(false);
      _activity.setListening(null);
      _bump();
      _emit(_state.copyWith(playing: false));
      _broadcast();
      return false;
    }
    return true;
  }

  Future<void> _saveProgress() async {
    final chapterId = _state.chapterId;
    final bookId = _state.bookId;
    if (chapterId == null || bookId == null || _paragraphs.isEmpty) return;
    try {
      await _library.saveProgress(
        bookId: bookId,
        chapterId: chapterId,
        paragraph: _state.paragraph,
        fraction: _state.paragraph / _paragraphs.length,
      );
    } catch (e) {
      debugPrint('Lưu tiến độ TTS lỗi: $e');
    }
  }

  // ─────────────────────────── điều khiển ───────────────────────────

  Future<void> _seekTo(int index) async {
    if (_units.isEmpty) return;
    _unitIdx = index.clamp(0, _units.length - 1);
    final wasPlaying = _playing;
    _bump();
    _publishPosition();
    unawaited(_saveProgress());
    if (wasPlaying) unawaited(_loop(++_gen));
  }

  Future<void> nextSentence() async {
    if (_unitIdx + 1 >= _units.length) return skipToNext();
    await _seekTo(_unitIdx + 1);
  }

  Future<void> previousSentence() => _seekTo(_unitIdx - 1);

  /// Nhảy tới đoạn [paragraph] trong chương đang nạp.
  Future<void> seekToParagraph(int paragraph) async {
    final idx = _units.indexWhere((u) => u.paragraph >= paragraph);
    await _seekTo(idx < 0 ? _units.length - 1 : idx);
  }

  @override
  Future<void> skipToNext() => _changeChapter(forward: true);

  @override
  Future<void> skipToPrevious() => _changeChapter(forward: false);

  Future<void> _changeChapter({required bool forward}) async {
    final id = _state.chapterId;
    if (id == null) return;
    final target = forward
        ? await _library.nextChapter(id)
        : await _library.previousChapter(id);
    if (target == null) return;
    final wasPlaying = _playing;
    _bump();
    if (!await _loadChapter(target.id, 0, null)) return;
    unawaited(_saveProgress());
    if (wasPlaying) unawaited(_loop(++_gen));
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'nextSentence') await nextSentence();
    if (name == 'previousSentence') await previousSentence();
  }

  Future<void> changeSpeed(double value) async {
    configure(speed: value);
    await _restartCurrentSentence();
  }

  Future<void> changePitch(double value) async {
    configure(pitch: value);
    await _restartCurrentSentence();
  }

  /// Áp giọng/tốc độ mới ngay bằng cách đọc lại câu hiện tại.
  Future<void> _restartCurrentSentence() async {
    if (!_playing) return;
    _bump();
    if (!await _applyConfig()) return;
    unawaited(_loop(++_gen));
  }

  // ─────────────────────────── hẹn giờ ───────────────────────────

  void startSleepTimer(Duration d) {
    _sleep.startDuration(d, _clock());
    _startSleepTicker();
    _refreshSleepState();
  }

  void startSleepEndOfChapter() {
    _sleep.startEndOfChapter();
    _startSleepTicker();
    _refreshSleepState();
  }

  void cancelSleepTimer() {
    _cancelSleep();
    unawaited(_tts.setVolume(1.0));
  }

  void _cancelSleep() {
    _sleep.cancel();
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _refreshSleepState();
  }

  void _startSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onSleepTick(),
    );
  }

  void _onSleepTick() {
    final now = _clock();
    if (_sleep.consumeExpired(now)) {
      _sleepTicker?.cancel();
      _sleepTicker = null;
      unawaited(pause().then((_) => _tts.setVolume(1.0)));
      _refreshSleepState();
      return;
    }
    if (_sleep.mode == SleepTimerMode.duration && _playing) {
      final f = _sleep.volumeFactor(now);
      if (f < 1) unawaited(_tts.setVolume(f));
    }
    _refreshSleepState();
  }

  void _refreshSleepState() {
    final remaining = _sleep.remaining(_clock());
    _emit(
      _state.copyWith(
        sleepMode: _sleep.mode,
        sleepRemaining: remaining,
        clearSleepRemaining: remaining == null,
      ),
    );
  }

  // ─────────────────────────── thông báo media ───────────────────────────

  void _broadcast() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.playPause},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _state.chapterId == null
            ? AudioProcessingState.idle
            : (_state.loading
                  ? AudioProcessingState.loading
                  : AudioProcessingState.ready),
        playing: _playing,
        speed: _speed,
        updatePosition: Duration.zero,
      ),
    );
  }
}
