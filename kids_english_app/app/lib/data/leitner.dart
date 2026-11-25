/// Ôn tập Leitner đơn giản: box 1..5.
const List<int> leitnerIntervalDays = [0, 0, 1, 3, 7, 14]; // index = box (0 không dùng)

class WordStat {
  final int exposures;
  final int correct;
  final int wrong;
  final int box;
  final DateTime nextReview;

  const WordStat({
    this.exposures = 0,
    this.correct = 0,
    this.wrong = 0,
    this.box = 1,
    required this.nextReview,
  });

  /// "Đã thuộc" khi box >= 3.
  bool get mastered => box >= 3;

  ///
  /// Quy tắc: sai → về box 1 (ôn ngay hôm nay); đúng chỉ thăng box khi từ đang đến hạn,
  /// đúng khi chưa đến hạn (vd. nhiều lần trong cùng ngày) chỉ tăng bộ đếm, giữ nguyên box/nextReview.
  WordStat update({required bool isCorrect, required DateTime now}) {
    final day = DateTime(now.year, now.month, now.day);
    if (isCorrect && !isDue(now)) {
      return WordStat(
        exposures: exposures + 1,
        correct: correct + 1,
        wrong: wrong,
        box: box,
        nextReview: nextReview,
      );
    }
    final newBox = isCorrect ? (box + 1).clamp(1, 5) : 1;
    return WordStat(
      exposures: exposures + 1,
      correct: correct + (isCorrect ? 1 : 0),
      wrong: wrong + (isCorrect ? 0 : 1),
      box: newBox,
      nextReview: day.add(Duration(days: leitnerIntervalDays[newBox])),
    );
  }

  bool isDue(DateTime now) => !nextReview.isAfter(now);

  Map<String, dynamic> toJson() => {
        'exposures': exposures,
        'correct': correct,
        'wrong': wrong,
        'box': box,
        'nextReview': nextReview.toIso8601String(),
      };

  factory WordStat.fromJson(Map json) => WordStat(
        exposures: (json['exposures'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        wrong: (json['wrong'] as num?)?.toInt() ?? 0,
        box: (json['box'] as num?)?.toInt() ?? 1,
        nextReview: DateTime.tryParse((json['nextReview'] ?? '') as String) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
