import 'dart:math';

import 'package:be_vui_tieng_anh/data/leitner.dart';
import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/data/review_planner.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 25, 10);
final yesterday = DateTime(2026, 11, 24);
final tomorrow = DateTime(2026, 11, 26);
final nextWeek = DateTime(2026, 12, 2);

Word word(String id) =>
    Word(id: id, text: id, image: 'images/$id.png', audio: 'audio/$id.mp3', sentence: '', sentenceAudio: 'audio/${id}_s.mp3', vi: 'vi_$id');

Topic topic(String id, List<String> wordIds, {String? baseDir, List<Lesson> lessons = const []}) => Topic(
      id: id,
      level: 1,
      order: 1,
      titleEn: 'T $id',
      titleVi: 'Chủ đề $id',
      mapIcon: '',
      song: null,
      words: [for (final w in wordIds) word(w)],
      sentences: const [],
      lessons: lessons,
      commands: const [],
      baseDir: baseDir,
    );

Lesson lesson(String id, List<String> newWords) =>
    Lesson(id: id, order: 1, newWords: newWords, sentenceId: null, steps: const [], parentTip: null);

WordStat stat({required int box, int wrong = 0, required DateTime next}) =>
    WordStat(exposures: 3, correct: 1, wrong: wrong, box: box, nextReview: next);

ReviewSummary summarize(List<Topic> topics, Map<String, WordStat> stats, {Set<String> doneLessons = const {}}) =>
    buildReviewSummary(
      topics: topics,
      isLessonDone: doneLessons.contains,
      wordStat: (id) => stats[id],
      now: now,
    );

void main() {
  // 10 từ ở 3 chủ đề: t01 built-in, t06 + t07 là gói đã cài.
  final topics10 = [
    topic('t01', ['t01_a', 't01_b', 't01_c', 't01_d']),
    topic('t06', ['t06_a', 't06_b', 't06_c'], baseDir: '/packs/t06'),
    topic('t07', ['t07_a', 't07_b', 't07_c'], baseDir: '/packs/t07'),
  ];
  // 4 từ cần ôn (box 1), 3 đang củng cố (box 2, chưa đến hạn), 3 đã thuộc (box 4, chưa đến hạn).
  final stats10 = <String, WordStat>{
    't01_a': stat(box: 1, wrong: 2, next: yesterday),
    't01_b': stat(box: 1, wrong: 0, next: yesterday),
    't06_a': stat(box: 1, wrong: 5, next: yesterday),
    't07_a': stat(box: 1, wrong: 1, next: yesterday),
    't01_c': stat(box: 2, next: tomorrow),
    't06_b': stat(box: 2, next: tomorrow),
    't07_b': stat(box: 2, next: tomorrow),
    't01_d': stat(box: 4, next: nextWeek),
    't06_c': stat(box: 4, next: nextWeek),
    't07_c': stat(box: 4, next: DateTime(2026, 12, 9)),
  };

  group('Kho từ & phân nhóm', () {
    test('< 4 từ → không mở ôn tập', () {
      final s = summarize([
        topic('t01', ['a', 'b', 'c'])
      ], {
        'a': stat(box: 1, next: now),
        'b': stat(box: 1, next: now),
        'c': stat(box: 1, next: now),
      });
      expect(s.learnedWords.length, 3);
      expect(s.canReview, isFalse);
      expect(buildSessionWords(s, random: Random(1)), isEmpty);
    });

    test('đúng 4 từ → mở, sessionSize = 4', () {
      final s = summarize([
        topic('t01', ['a', 'b', 'c', 'd'])
      ], {
        for (final id in ['a', 'b', 'c', 'd']) id: stat(box: 1, next: now),
      });
      expect(s.canReview, isTrue);
      expect(s.sessionSize, 4);
      expect(buildSessionWords(s, random: Random(1)), hasLength(4));
    });

    test('mỗi từ thuộc đúng 1 nhóm; learned = hợp 3 nhóm', () {
      final s = summarize(topics10, stats10);
      final ids = [
        for (final g in [s.dueOrWeakWords, s.learningWords, s.masteredWords]) ...g.map((w) => w.id),
      ];
      expect(ids.toSet().length, ids.length);
      expect(ids.toSet(), s.learnedWords.map((w) => w.id).toSet());
      expect(s.dueOrWeakWords.map((w) => w.id).toSet(), {'t01_a', 't01_b', 't06_a', 't07_a'});
      expect(s.learningWords.map((w) => w.id).toSet(), {'t01_c', 't06_b', 't07_b'});
      expect(s.masteredWords.map((w) => w.id).toSet(), {'t01_d', 't06_c', 't07_c'});
    });

    test('box >= 2 nhưng đã đến hạn → vào nhóm cần ôn', () {
      final s = summarize([
        topic('t01', ['a', 'b', 'c', 'd'])
      ], {
        'a': stat(box: 4, next: yesterday), // quá hạn
        'b': stat(box: 2, next: now), // đến hạn đúng hôm nay
        'c': stat(box: 3, next: tomorrow),
        'd': stat(box: 2, next: tomorrow),
      });
      expect(s.dueOrWeakWords.map((w) => w.id).toSet(), {'a', 'b'});
      expect(s.masteredWords.map((w) => w.id), ['c']);
      expect(s.learningWords.map((w) => w.id), ['d']);
    });

    test('từ của bài đã xong (chưa có stat) vẫn là từ đã học và thuộc nhóm cần ôn', () {
      final s = summarize([
        topic('t01', ['a', 'b', 'c', 'd', 'e'], lessons: [
          lesson('l1', ['a', 'b', 'c', 'd'])
        ])
      ], {}, doneLessons: {'l1'});
      expect(s.learnedWords.map((w) => w.id), ['a', 'b', 'c', 'd']); // e chưa học
      expect(s.dueOrWeakWords.length, 4);
      expect(s.dueOrWeakWords.first.stat, isNull);
    });

    test('bài chưa xong và chưa có stat → không tính', () {
      final s = summarize([
        topic('t01', ['a', 'b'], lessons: [
          lesson('l1', ['a', 'b'])
        ])
      ], {});
      expect(s.learnedWords, isEmpty);
    });

    test('từ của gói đã gỡ (stat còn nhưng chủ đề không nạp) bị bỏ qua, không crash', () {
      final s = summarize([
        topic('t01', ['t01_a', 't01_b', 't01_c', 't01_d'])
      ], {
        't01_a': stat(box: 1, next: now),
        't01_b': stat(box: 1, next: now),
        't01_c': stat(box: 1, next: now),
        't01_d': stat(box: 1, next: now),
        't06_a': stat(box: 1, next: now), // gói t06 đã gỡ
        't06_b': stat(box: 1, next: now),
      });
      expect(s.learnedWords.map((w) => w.id), ['t01_a', 't01_b', 't01_c', 't01_d']);
      expect(buildSessionWords(s, random: Random(3)).every((w) => w.id.startsWith('t01_')), isTrue);
    });

    test('giữ đúng baseDir và tiêu đề chủ đề cho từng từ', () {
      final s = summarize(topics10, stats10);
      final byId = {for (final w in s.learnedWords) w.id: w};
      expect(byId['t01_a']!.baseDir, isNull);
      expect(byId['t06_a']!.baseDir, '/packs/t06');
      expect(byId['t07_c']!.baseDir, '/packs/t07');
      expect(byId['t06_b']!.topicId, 't06');
      expect(byId['t06_b']!.topicTitleVi, 'Chủ đề t06');
    });

    test('loại trùng theo word.id khi hai chủ đề cùng chứa từ', () {
      final s = summarize([
        topic('t01', ['x', 'a', 'b', 'c']),
        topic('t02', ['x', 'd']),
      ], {
        for (final id in ['x', 'a', 'b', 'c', 'd']) id: stat(box: 1, next: now),
      });
      expect(s.learnedWords.where((w) => w.id == 'x'), hasLength(1));
      expect(s.learnedWords.length, 5);
    });
  });

  group('smartMix', () {
    test('10 từ đa chủ đề → 6 từ đúng tỷ lệ 3/2/1, không trùng, đúng baseDir', () {
      final s = summarize(topics10, stats10);
      final picked = buildSessionWords(s, random: Random(7));
      expect(picked, hasLength(6));
      expect(picked.map((w) => w.id).toSet().length, 6);
      final due = s.dueOrWeakWords.map((w) => w.id).toSet();
      final learning = s.learningWords.map((w) => w.id).toSet();
      final mastered = s.masteredWords.map((w) => w.id).toSet();
      expect(picked.where((w) => due.contains(w.id)).length, 3);
      expect(picked.where((w) => learning.contains(w.id)).length, 2);
      expect(picked.where((w) => mastered.contains(w.id)).length, 1);
      for (final w in picked) {
        expect(w.baseDir, w.id.startsWith('t01') ? isNull : '/packs/${w.id.substring(0, 3)}', reason: w.id);
      }
    });

    test('3 từ cần ôn là những từ ưu tiên nhất (box thấp → sai nhiều)', () {
      final s = summarize(topics10, stats10);
      final picked = buildSessionWords(s, random: Random(1)).map((w) => w.id).toSet();
      // due: t06_a (sai 5), t01_a (sai 2), t07_a (sai 1), t01_b (sai 0) → bỏ t01_b.
      expect(picked.containsAll({'t06_a', 't01_a', 't07_a'}), isTrue);
      expect(picked.contains('t01_b'), isFalse);
    });

    test('từ đã thuộc được chọn là từ có nextReview cũ nhất', () {
      final s = summarize(topics10, stats10);
      final picked = buildSessionWords(s, random: Random(1)).map((w) => w.id).toSet();
      expect(picked.contains('t01_d') || picked.contains('t06_c'), isTrue);
      expect(picked.contains('t07_c'), isFalse); // nextReview mới nhất
    });

    test('thiếu nhóm thì bù: toàn box 1 → 6 từ đều lấy từ nhóm cần ôn', () {
      final ids = [for (var i = 0; i < 9; i++) 'w$i'];
      final s = summarize([topic('t01', ids)], {for (final id in ids) id: stat(box: 1, next: yesterday)});
      final picked = buildSessionWords(s, random: Random(2));
      expect(picked, hasLength(6));
      expect(picked.map((w) => w.id).toSet().length, 6);
    });

    test('thiếu nhóm cần ôn: bù từ củng cố rồi đã thuộc', () {
      final ids = [for (var i = 0; i < 8; i++) 'w$i'];
      final stats = {
        'w0': stat(box: 1, next: yesterday), // 1 cần ôn
        for (var i = 1; i <= 3; i++) 'w$i': stat(box: 2, next: tomorrow), // 3 củng cố
        for (var i = 4; i <= 7; i++) 'w$i': stat(box: 5, next: nextWeek), // 4 đã thuộc
      };
      final s = summarize([topic('t01', ids)], stats);
      final picked = buildSessionWords(s, random: Random(5));
      expect(picked, hasLength(6));
      final p = picked.map((w) => w.id).toSet();
      expect(p.contains('w0'), isTrue);
      expect(p.where((id) => ['w1', 'w2', 'w3'].contains(id)).length, 3); // 2 + 1 bù từ nhóm 2
      expect(p.where((id) => ['w4', 'w5', 'w6', 'w7'].contains(id)).length, 2);
    });

    test('kho 5 từ → phiên 5 từ', () {
      final ids = ['a', 'b', 'c', 'd', 'e'];
      final s = summarize([topic('t01', ids)], {for (final id in ids) id: stat(box: 1, next: now)});
      expect(buildSessionWords(s, random: Random(1)), hasLength(5));
    });

    test('tất định: cùng seed → cùng kết quả (cả thứ tự)', () {
      final s = summarize(topics10, stats10);
      final a = buildSessionWords(s, random: Random(42)).map((w) => w.id).toList();
      final b = buildSessionWords(s, random: Random(42)).map((w) => w.id).toList();
      expect(a, b);
    });
  });

  group('weakWordsOnly', () {
    test('ưu tiên box 1 / sai nhiều, tối đa 6 từ', () {
      final ids = [for (var i = 0; i < 9; i++) 'w$i'];
      final stats = {
        for (var i = 0; i < 9; i++) 'w$i': stat(box: 1, wrong: i, next: yesterday), // w8 sai nhiều nhất
      };
      final s = summarize([topic('t01', ids)], stats);
      final picked = buildSessionWords(s, mode: ReviewMode.weakWordsOnly, random: Random(1));
      expect(picked.map((w) => w.id).toSet(), {'w8', 'w7', 'w6', 'w5', 'w4', 'w3'});
    });

    test('box 1 được ưu tiên hơn từ quá hạn ở box cao', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      final stats = {
        'a': stat(box: 4, wrong: 9, next: yesterday),
        'b': stat(box: 3, wrong: 9, next: yesterday),
        for (final id in ['c', 'd', 'e', 'f', 'g', 'h']) id: stat(box: 1, wrong: 0, next: yesterday),
      };
      final s = summarize([topic('t01', ids)], stats);
      final picked = buildSessionWords(s, mode: ReviewMode.weakWordsOnly, random: Random(1));
      expect(picked.map((w) => w.id).toSet(), {'c', 'd', 'e', 'f', 'g', 'h'});
    });

    test('ít từ cần ôn → bù cho đủ 4 (củng cố trước, rồi đã thuộc)', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
      final stats = {
        'a': stat(box: 1, wrong: 1, next: yesterday),
        'b': stat(box: 2, next: tomorrow),
        'c': stat(box: 5, next: nextWeek),
        'd': stat(box: 5, next: nextWeek),
        'e': stat(box: 5, next: nextWeek),
        'f': stat(box: 5, next: nextWeek),
      };
      final s = summarize([topic('t01', ids)], stats);
      final picked = buildSessionWords(s, mode: ReviewMode.weakWordsOnly, random: Random(1));
      expect(picked, hasLength(4));
      final p = picked.map((w) => w.id).toSet();
      expect(p.contains('a'), isTrue);
      expect(p.contains('b'), isTrue);
    });

    test('đủ ≥ 4 từ cần ôn thì không bù thêm', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
      final stats = {
        for (final id in ['a', 'b', 'c', 'd']) id: stat(box: 1, next: yesterday),
        'e': stat(box: 2, next: tomorrow),
        'f': stat(box: 5, next: nextWeek),
      };
      final s = summarize([topic('t01', ids)], stats);
      final picked = buildSessionWords(s, mode: ReviewMode.weakWordsOnly, random: Random(1));
      expect(picked.map((w) => w.id).toSet(), {'a', 'b', 'c', 'd'});
    });
  });

  group('sortByPriority', () {
    test('box tăng dần → sai giảm dần → nextReview cũ trước', () {
      final s = summarize([
        topic('t01', ['a', 'b', 'c', 'd'])
      ], {
        'a': stat(box: 2, wrong: 0, next: yesterday),
        'b': stat(box: 1, wrong: 1, next: yesterday),
        'c': stat(box: 1, wrong: 3, next: yesterday),
        'd': stat(box: 1, wrong: 3, next: DateTime(2026, 11, 20)),
      });
      expect(sortByPriority(s.learnedWords).map((w) => w.id), ['d', 'c', 'b', 'a']);
    });
  });

  group('ReviewOutcome (gom kết quả phiên)', () {
    test('lần chấm điểm đầu tiên của từ quyết định, các lần sau bị bỏ qua', () {
      final o = ReviewOutcome();
      o.record('a', false);
      o.record('a', true);
      o.record('a', true);
      o.record('b', true);
      o.record('b', false);
      expect(o.results, {'a': false, 'b': true});
    });

    test('từ không có lần chấm điểm nào → không có kết quả', () {
      final o = ReviewOutcome(allowedWordIds: ['a', 'b', 'c']);
      o.record('a', true);
      expect(o.results.keys, ['a']);
      expect(o.isEmpty, isFalse);
      expect(ReviewOutcome().isEmpty, isTrue);
    });

    test('bỏ qua từ ngoài phiên', () {
      final o = ReviewOutcome(allowedWordIds: ['a']);
      o.record('zzz', true);
      expect(o.isEmpty, isTrue);
    });

    test('flush ghi mỗi từ đúng 1 lần theo kết quả đầu tiên', () async {
      final o = ReviewOutcome();
      o.record('a', false);
      o.record('b', true);
      o.record('a', true);
      final written = <String, bool>{};
      var calls = 0;
      await o.flush((id, ok) async {
        calls++;
        written[id] = ok;
      });
      expect(calls, 2);
      expect(written, {'a': false, 'b': true});
    });

    test('Memory/Repeat không gọi record → không có gì để ghi; thoát giữa chừng (không flush) → không ghi', () async {
      final o = ReviewOutcome(allowedWordIds: ['a']);
      var calls = 0;
      await o.flush((id, ok) async => calls++);
      expect(calls, 0);
      o.record('a', true);
      // thoát giữa chừng: người gọi không flush
      expect(calls, 0);
    });

    test('áp kết quả vào Leitner: sai lần đầu → box 1; đúng lần đầu khi đến hạn → lên box', () {
      final o = ReviewOutcome()
        ..record('a', false)
        ..record('a', true)
        ..record('b', true);
      var a = stat(box: 3, next: yesterday);
      var b = stat(box: 1, next: yesterday);
      a = a.update(isCorrect: o.results['a']!, now: now);
      b = b.update(isCorrect: o.results['b']!, now: now);
      expect(a.box, 1);
      expect(a.wrong, 1);
      expect(b.box, 2);
      expect(b.nextReview, DateTime(2026, 11, 26));
    });
  });
}
