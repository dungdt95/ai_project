/// Ôn tập thông minh: gom kho từ đã học, phân nhóm theo Leitner và chọn từ cho một phiên ôn.
/// Thuần Dart (không phụ thuộc UI); `now` và `Random` được truyền vào để test tất định.
library;

import 'dart:math';

import 'leitner.dart';
import 'models.dart';

/// Số từ tối thiểu để mở ôn tập.
const int kReviewMinWords = 4;

/// Số từ tối đa trong một phiên.
const int kReviewSessionMax = 6;

enum ReviewMode { smartMix, weakWordsOnly }

class ReviewWord {
  const ReviewWord({
    required this.word,
    required this.topicId,
    required this.topicTitleEn,
    required this.topicTitleVi,
    required this.baseDir,
    required this.stat,
  });

  final Word word;
  final String topicId;
  final String topicTitleEn;
  final String topicTitleVi;

  /// null = built-in (assets); khác null = thư mục gói đã cài.
  final String? baseDir;
  final WordStat? stat;

  String get id => word.id;
  int get box => stat?.box ?? 1;
  int get wrong => stat?.wrong ?? 0;
  bool get isMastered => stat?.mastered ?? false;
  bool isDue(DateTime now) => stat == null ? true : stat!.isDue(now);
  DateTime get _nextReview => stat?.nextReview ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Kho từ của bé, chia 3 nhóm không chồng lấn (mỗi từ đúng 1 nhóm).
class ReviewSummary {
  const ReviewSummary({
    required this.learnedWords,
    required this.masteredWords,
    required this.learningWords,
    required this.dueOrWeakWords,
  });

  static const empty = ReviewSummary(
    learnedWords: [],
    masteredWords: [],
    learningWords: [],
    dueOrWeakWords: [],
  );

  final List<ReviewWord> learnedWords;

  /// Box 3..5 và chưa đến hạn.
  final List<ReviewWord> masteredWords;

  /// Box 2 và chưa đến hạn.
  final List<ReviewWord> learningWords;

  /// Chưa có thống kê, hoặc box 1, hoặc đã đến hạn.
  final List<ReviewWord> dueOrWeakWords;

  /// Đủ từ để mở ôn tập.
  bool get canReview => learnedWords.length >= kReviewMinWords;

  int get sessionSize => min(kReviewSessionMax, learnedWords.length);
}

/// Dựng kho từ đã học = từ của bài đã xong ∪ từ đã có WordStat; chỉ tính từ có trong [topics] đang nạp.
ReviewSummary buildReviewSummary({
  required List<Topic> topics,
  required bool Function(String lessonId) isLessonDone,
  required WordStat? Function(String wordId) wordStat,
  required DateTime now,
}) {
  final seen = <String>{};
  final learned = <ReviewWord>[];
  for (final t in topics) {
    final fromLessons = <String>{
      for (final l in t.lessons)
        if (isLessonDone(l.id)) ...l.newWords,
    };
    for (final w in t.words) {
      if (seen.contains(w.id)) continue;
      final stat = wordStat(w.id);
      if (stat == null && !fromLessons.contains(w.id)) continue;
      seen.add(w.id);
      learned.add(ReviewWord(
        word: w,
        topicId: t.id,
        topicTitleEn: t.titleEn,
        topicTitleVi: t.titleVi,
        baseDir: t.baseDir,
        stat: stat,
      ));
    }
  }

  final due = <ReviewWord>[];
  final learning = <ReviewWord>[];
  final mastered = <ReviewWord>[];
  for (final w in learned) {
    if (w.stat == null || w.box == 1 || w.isDue(now)) {
      due.add(w);
    } else if (w.box == 2) {
      learning.add(w);
    } else {
      mastered.add(w);
    }
  }
  return ReviewSummary(
    learnedWords: learned,
    masteredWords: mastered,
    learningWords: learning,
    dueOrWeakWords: due,
  );
}

/// Thứ tự ưu tiên: box tăng dần → sai nhiều trước → đến hạn lâu nhất trước (id làm tie-break để tất định).
int _byPriority(ReviewWord a, ReviewWord b) {
  var c = a.box.compareTo(b.box);
  if (c != 0) return c;
  c = b.wrong.compareTo(a.wrong);
  if (c != 0) return c;
  c = a._nextReview.compareTo(b._nextReview);
  if (c != 0) return c;
  return a.id.compareTo(b.id);
}

/// Sắp theo mức cần ôn nhất trước (không sửa danh sách gốc).
List<ReviewWord> sortByPriority(Iterable<ReviewWord> words) => words.toList()..sort(_byPriority);

int _byOldest(ReviewWord a, ReviewWord b) {
  final c = a._nextReview.compareTo(b._nextReview);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// Chọn từ cho một phiên ôn. Trả về danh sách đã xáo trộn thứ tự hiển thị; rỗng nếu chưa đủ [kReviewMinWords] từ.
List<ReviewWord> buildSessionWords(
  ReviewSummary summary, {
  ReviewMode mode = ReviewMode.smartMix,
  required Random random,
}) {
  if (!summary.canReview) return const [];
  final due = sortByPriority(summary.dueOrWeakWords);
  final learning = List.of(summary.learningWords)..shuffle(random);
  final mastered = List.of(summary.masteredWords)..sort(_byOldest);

  final picked = <ReviewWord>[];
  if (mode == ReviewMode.weakWordsOnly) {
    picked.addAll(due.take(kReviewSessionMax));
    // Bù cho đủ tối thiểu để các trò chơi có đủ thẻ.
    for (final w in [...learning, ...mastered]) {
      if (picked.length >= kReviewMinWords) break;
      picked.add(w);
    }
  } else {
    final size = summary.sessionSize;
    picked
      ..addAll(due.take(3))
      ..addAll(learning.take(2))
      ..addAll(mastered.take(1));
    // Thiếu thì bù theo thứ tự nhóm 1 → 2 → 3.
    for (final w in [...due.skip(3), ...learning.skip(2), ...mastered.skip(1)]) {
      if (picked.length >= size) break;
      picked.add(w);
    }
  }
  return picked..shuffle(random);
}

/// Gom kết quả một phiên ôn (rule L4): mỗi từ chỉ ghi 1 lần, theo lần trả lời có chấm điểm ĐẦU TIÊN.
/// Chỉ các hoạt động có chấm điểm (Tap & Find, Drag & Drop…) mới gọi [record].
class ReviewOutcome {
  ReviewOutcome({Iterable<String>? allowedWordIds}) : _allowed = allowedWordIds?.toSet();

  final Set<String>? _allowed;
  final Map<String, bool> _first = {}; // giữ thứ tự thêm vào

  void record(String wordId, bool isCorrect) {
    if (_allowed != null && !_allowed.contains(wordId)) return;
    _first.putIfAbsent(wordId, () => isCorrect);
  }

  /// Kết quả theo từ (chỉ từ có ít nhất một lần chấm điểm).
  Map<String, bool> get results => Map.unmodifiable(_first);

  bool get isEmpty => _first.isEmpty;

  /// Ghi toàn bộ kết quả (gọi khi kết thúc phiên); thoát giữa chừng thì không gọi.
  Future<void> flush(Future<void> Function(String wordId, bool isCorrect) write) async {
    for (final e in _first.entries) {
      await write(e.key, e.value);
    }
  }
}
