import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../activities/celebrate_activity.dart';
import '../activities/discover_activity.dart';
import '../activities/drag_drop_activity.dart';
import '../activities/memory_match_activity.dart';
import '../activities/repeat_record_activity.dart';
import '../activities/simon_says_activity.dart';
import '../activities/tap_find_activity.dart';
import '../activities/warmup_activity.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.topicId,
    required this.lessonId,
  });

  final String topicId;
  final String lessonId;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  int _stepIndex = 0;

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Quit lesson?', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return result ?? false;
  }

  void _onStepFinished(Lesson lesson, List<Word> words) {
    if (_stepIndex + 1 < lesson.steps.length) {
      setState(() => _stepIndex++);
    } else {
      _completeLesson(lesson, words);
    }
  }

  Future<void> _completeLesson(Lesson lesson, List<Word> words) async {
    final profile = ref.read(activeProfileProvider);
    final storage = ref.read(storageProvider);

    if (profile != null) {
      for (final w in words) {
        await storage.recordWordAttempt(profile.id, w.id, correct: true);
      }
      await storage.completeLesson(profile.id, lesson.id, stars: 3);
      ref.read(progressVersionProvider.notifier).bump();
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider).value;
    final topic = topics?.where((t) => t.id == widget.topicId).firstOrNull;
    final lesson = topic?.lessons.where((l) => l.id == widget.lessonId).firstOrNull;

    if (topic == null || lesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final words = [for (final id in lesson.newWords) topic.wordById(id)!];
    final allTopicWords = topic.words;
    final currentStep = lesson.steps[_stepIndex];
    final audio = ref.read(audioProvider);

    Widget buildCurrentStepWidget() {
      switch (currentStep.type) {
        case 'warmup':
          return WarmupActivity(
            lesson: lesson,
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text, {viText}) => audio.instruction(path, text, viText: viText),
          );
        case 'discover':
          return DiscoverActivity(
            words: words,
            baseDir: topic.baseDir,
            showViHint: ref.watch(settingsProvider).viHints,
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text, {viText}) => audio.playWord(path, text, viText: viText, baseDir: topic.baseDir),
          );
        case 'tap_find':
          return TapFindActivity(
            words: words,
            allTopicWords: allTopicWords,
            rounds: currentStep.rounds,
            baseDir: topic.baseDir,
            onWordAttempt: (id, correct) {
              final profile = ref.read(activeProfileProvider);
              if (profile != null) {
                ref.read(storageProvider).recordWordAttempt(profile.id, id, correct: correct);
              }
            },
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text) => audio.play(path, text, baseDir: topic.baseDir),
          );
        case 'memory_match':
          return MemoryMatchActivity(
            words: words,
            baseDir: topic.baseDir,
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text) => audio.play(path, text, baseDir: topic.baseDir),
          );
        case 'drag_drop':
          return DragDropActivity(
            words: words,
            baseDir: topic.baseDir,
            onWordAttempt: (id, correct) {
              final profile = ref.read(activeProfileProvider);
              if (profile != null) {
                ref.read(storageProvider).recordWordAttempt(profile.id, id, correct: correct);
              }
            },
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text) => audio.play(path, text, baseDir: topic.baseDir),
          );
        case 'repeat_record':
          return RepeatRecordActivity(
            words: words,
            baseDir: topic.baseDir,
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text) => audio.play(path, text, baseDir: topic.baseDir),
          );
        case 'simon_says':
          final cmds = [
            for (final cmdId in (currentStep.data['commands'] as List? ?? const []))
              topic.commands.where((c) => c.id == cmdId).firstOrNull
          ].whereType<Command>().toList();

          return SimonSaysActivity(
            commands: cmds.isNotEmpty ? cmds : topic.commands,
            baseDir: topic.baseDir,
            onFinished: () => _onStepFinished(lesson, words),
            playAudio: (path, text) => audio.play(path, text, baseDir: topic.baseDir),
          );
        case 'celebrate':
          final sticker = currentStep.sticker != null ? 'images/stickers/${currentStep.sticker}.png' : null;
          return CelebrateActivity(
            stickerPath: sticker,
            baseDir: topic.baseDir,
            onFinished: () => _completeLesson(lesson, words),
            playAudio: (path, text, {viText}) => audio.instruction(path, text, viText: viText),
          );
        default:
          return Center(
            child: FilledButton(
              onPressed: () => _onStepFinished(lesson, words),
              child: const Text('Next Step'),
            ),
          );
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmExit();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.sky,
        body: SafeArea(
          child: Stack(
            children: [
              // Nút thoát Home
              Positioned(
                left: 16,
                top: 12,
                child: IconButton.filled(
                  iconSize: 32,
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                  icon: const Icon(Icons.home_rounded, color: AppColors.ink),
                  onPressed: () async {
                    if (await _confirmExit() && context.mounted) {
                      context.pop();
                    }
                  },
                ),
              ),

              // Thanh tiến trình bước học (Dấu chân / Ngôi sao)
              Positioned(
                top: 16,
                left: 96,
                right: 96,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(lesson.steps.length, (i) {
                      final isCurrent = i == _stepIndex;
                      final isDone = i < _stepIndex;
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

              // Nội dung hoạt động chính
              Positioned.fill(
                top: 60,
                child: buildCurrentStepWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
