import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/models.dart';
import '../../data/review_planner.dart';
import '../activities/balloon_pop_activity.dart';
import '../activities/celebrate_activity.dart';
import '../activities/drag_drop_activity.dart';
import '../activities/feed_momo_activity.dart';
import '../activities/memory_match_activity.dart';
import '../activities/repeat_record_activity.dart';
import '../activities/speech_capture.dart';
import '../activities/tap_find_activity.dart';
import '../screen_time/screen_time_controller.dart';

/// Danh sách từ + bản đồ thư mục được chốt MỘT lần khi mở phiên (không tính lại giữa chừng).
class _Plan {
  _Plan({
    required this.profileId,
    required this.sessionWords,
    required this.priorityWords,
    required this.memoryWords,
    required this.learnedWords,
    required this.wordDirs,
    required this.audioDirs,
    required this.useBalloonPop,
    required this.useFeedMomo,
  }) : outcome = ReviewOutcome(allowedWordIds: sessionWords.map((w) => w.id));

  final String profileId;
  final List<Word> sessionWords;
  final List<Word> priorityWords; // cần ôn nhất trước
  final List<Word> memoryWords;
  final List<Word> learnedWords; // đáp án nhiễu cho Tap & Find
  final Map<String, String?> wordDirs; // wordId → baseDir (null = built-in)
  final Map<String, String?> audioDirs; // đường dẫn âm thanh → baseDir
  final bool useBalloonPop; // chặng 1: Balloon Pop thay cho Tap & Find
  final bool useFeedMomo; // chặng 3: Feed Momo thay cho Drag & Drop
  final ReviewOutcome outcome;
}

/// Phiên ôn tập: 4 chặng + chúc mừng. Chỉ Tap & Find / Drag & Drop được chấm điểm (rule L5);
/// kết quả ghi vào Leitner một lần khi xong cả 4 chặng (rule L4).
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({
    super.key,
    this.mode = ReviewMode.smartMix,
    this.random,
    this.capture,
    this.recordDuration = const Duration(seconds: 3),
    this.useBalloonPop,
    this.useFeedMomo,
  });

  final ReviewMode mode;

  /// Tiêm Random để test tất định.
  final Random? random;

  /// Tiêm bộ ghi âm giả cho test; null → micro thật.
  final SpeechCapture? capture;
  final Duration recordDuration;

  /// Ép biến thể mini-game (test tất định). null → chọn ngẫu nhiên một lần khi dựng phiên (G5).
  final bool? useBalloonPop;
  final bool? useFeedMomo;

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  static const _stageCount = 4;

  _Plan? _plan;
  late final AudioService _audio; // giữ sẵn: activity có thể phát âm trong post-frame sau khi màn đã gỡ (ref.read khi đó sẽ lỗi)
  int _stage = 0; // 0..3 = các chặng, 4 = chúc mừng
  bool _leaving = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioProvider);
    // Hết giờ chơi → "Momo đi ngủ" (ngoài vòng build). Đang giữa phiên thì không ngắt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving) return;
      if (ref.read(screenTimeProvider).isTimeUp) {
        _leaving = true;
        context.go('/sleep');
      }
    });
  }

  _Plan _buildPlan(ReviewSummary summary, String profileId) {
    final random = widget.random ?? Random();
    final session = buildSessionWords(summary, mode: widget.mode, random: random);
    final priority = sortByPriority(session);
    final memory = List.of(session)..shuffle(random);
    final balloon = widget.useBalloonPop ?? random.nextBool();
    final feed = widget.useFeedMomo ?? random.nextBool();
    final audioDirs = <String, String?>{};
    for (final rw in summary.learnedWords) {
      if (rw.word.audio.isNotEmpty) audioDirs[rw.word.audio] = rw.baseDir;
      if (rw.word.sentenceAudio.isNotEmpty) audioDirs[rw.word.sentenceAudio] = rw.baseDir;
    }
    return _Plan(
      profileId: profileId,
      sessionWords: [for (final w in session) w.word],
      priorityWords: [for (final w in priority) w.word],
      memoryWords: [for (final w in memory.take(3)) w.word],
      learnedWords: [for (final w in summary.learnedWords) w.word],
      wordDirs: {for (final w in summary.learnedWords) w.id: w.baseDir},
      audioDirs: audioDirs,
      useBalloonPop: balloon,
      useFeedMomo: feed,
    );
  }

  void _goHome() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
  }

  Future<void> _play(String? path, String text) {
    final dir = (path == null || path.isEmpty) ? null : _plan?.audioDirs[path];
    return _audio.play(path, text, baseDir: dir);
  }

  void _advance(int from) {
    if (!mounted || _stage != from || _leaving) return;
    setState(() => _stage++);
    if (_stage >= _stageCount) _complete();
  }

  /// Xong cả 4 chặng: ghi Leitner theo lần chấm điểm đầu tiên của mỗi từ rồi báo tiến độ đổi.
  Future<void> _complete() async {
    final plan = _plan;
    if (plan == null || _completed) return;
    _completed = true;
    final storage = ref.read(storageProvider);
    final progress = ref.read(progressVersionProvider.notifier); // lấy trước khi await (provider toàn cục, không bị huỷ theo màn)
    await plan.outcome.flush((id, correct) => storage.recordWordAttempt(plan.profileId, id, correct: correct));
    progress.bump();
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Quit review?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you want to go back to the map?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _goHome(); // thoát giữa chừng: không ghi gì
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);
    final profile = ref.watch(activeProfileProvider);

    if (!topicsAsync.hasValue && !topicsAsync.hasError) {
      return const Scaffold(backgroundColor: AppColors.sky, body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null && !_leaving) {
      final summary = ref.read(reviewSummaryProvider);
      if (profile == null || !summary.canReview) {
        _goHome(); // không có hồ sơ / chưa đủ từ → quay về an toàn
      } else {
        _plan = _buildPlan(summary, profile.id);
      }
    }
    final plan = _plan;
    if (plan == null) {
      return const Scaffold(backgroundColor: AppColors.sky, body: SizedBox.shrink());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stage >= _stageCount ? _goHome() : _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.sky,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 12,
                child: IconButton.filled(
                  key: const Key('review_exit'),
                  iconSize: 32,
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                  icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  onPressed: () => _stage >= _stageCount ? _goHome() : _confirmExit(),
                ),
              ),
              Positioned(
                top: 16,
                left: 96,
                right: 96,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_stageCount, (i) {
                      final isCurrent = i == _stage;
                      final isDone = i < _stage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          isDone
                              ? Icons.star_rounded
                              : (isCurrent ? Icons.star_half_rounded : Icons.star_border_rounded),
                          color: isDone || isCurrent ? AppColors.yellow : Colors.grey.shade400,
                          size: isCurrent ? 36 : 28,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Positioned.fill(top: 60, child: _stageWidget(plan)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageWidget(_Plan plan) {
    switch (_stage) {
      case 0:
        if (plan.useBalloonPop) {
          return BalloonPopActivity(
            key: const ValueKey('review_balloon_pop'),
            words: plan.sessionWords,
            allTopicWords: plan.learnedWords,
            rounds: 6,
            baseDir: null,
            wordBaseDirs: plan.wordDirs,
            onWordAttempt: plan.outcome.record,
            onFinished: () => _advance(0),
            playAudio: _play,
          );
        }
        return TapFindActivity(
          key: const ValueKey('review_tap_find'),
          words: plan.sessionWords,
          allTopicWords: plan.learnedWords,
          rounds: 6,
          baseDir: null,
          wordBaseDirs: plan.wordDirs,
          onWordAttempt: plan.outcome.record,
          onFinished: () => _advance(0),
          playAudio: _play,
        );
      case 1:
        return MemoryMatchActivity(
          key: const ValueKey('review_memory'),
          words: plan.memoryWords,
          baseDir: null,
          wordBaseDirs: plan.wordDirs,
          onFinished: () => _advance(1),
          playAudio: _play, // Memory Match không chấm điểm (L5)
        );
      case 2:
        if (plan.useFeedMomo) {
          return FeedMomoActivity(
            key: const ValueKey('review_feed_momo'),
            words: plan.priorityWords.take(4).toList(),
            baseDir: null,
            wordBaseDirs: plan.wordDirs,
            rounds: 4,
            onWordAttempt: plan.outcome.record,
            onFinished: () => _advance(2),
            playAudio: _play,
          );
        }
        return DragDropActivity(
          key: const ValueKey('review_drag_drop'),
          words: plan.priorityWords.take(4).toList(),
          baseDir: null,
          wordBaseDirs: plan.wordDirs,
          rounds: 4,
          onWordAttempt: plan.outcome.record,
          onFinished: () => _advance(2),
          playAudio: _play,
        );
      case 3:
        return RepeatRecordActivity(
          key: const ValueKey('review_repeat'),
          words: plan.priorityWords.take(2).toList(),
          baseDir: null,
          wordBaseDirs: plan.wordDirs,
          capture: widget.capture,
          recordDuration: widget.recordDuration,
          onFinished: () => _advance(3), // Repeat & Record không chấm điểm (L5)
          playAudio: _play,
        );
      default:
        return CelebrateActivity(
          key: const ValueKey('review_celebrate'),
          stickerPath: null,
          baseDir: null,
          title: 'You are a Review Super Star!',
          speech: 'Hooray! You are a Review Super Star!',
          speechVi: 'Bé là siêu sao ôn tập!',
          speechAudioPath: null,
          onFinished: _goHome,
          playAudio: (path, text, {viText}) => _audio.instruction(path, text, viText: viText),
        );
    }
  }
}
