/// Một dòng thống kê thô: (ngày, truyện).
class DailyStat {
  const DailyStat({
    required this.day,
    required this.bookId,
    this.readSeconds = 0,
    this.listenSeconds = 0,
    this.chaptersFinished = 0,
  });

  /// `yyyy-MM-dd` theo giờ địa phương.
  final String day;
  final int bookId;
  final int readSeconds;
  final int listenSeconds;
  final int chaptersFinished;
}

class StatTotals {
  const StatTotals({
    this.readSeconds = 0,
    this.listenSeconds = 0,
    this.chaptersFinished = 0,
  });

  final int readSeconds;
  final int listenSeconds;
  final int chaptersFinished;

  int get totalSeconds => readSeconds + listenSeconds;

  StatTotals operator +(StatTotals o) => StatTotals(
    readSeconds: readSeconds + o.readSeconds,
    listenSeconds: listenSeconds + o.listenSeconds,
    chaptersFinished: chaptersFinished + o.chaptersFinished,
  );
}

class DayPoint {
  const DayPoint(this.date, this.totals);

  final DateTime date;
  final StatTotals totals;
}

class StatsSummary {
  const StatsSummary({
    required this.today,
    required this.last7,
    required this.last30,
    required this.days,
    required this.streak,
    required this.perBook30,
  });

  final StatTotals today;
  final StatTotals last7;
  final StatTotals last30;

  /// 30 ngày gần nhất, cũ → mới, đủ cả ngày không có dữ liệu.
  final List<DayPoint> days;
  final int streak;

  /// bookId → tổng 30 ngày.
  final Map<int, StatTotals> perBook30;
}

class StatsAggregator {
  const StatsAggregator._();

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _active(StatTotals? t) =>
      t != null && (t.totalSeconds > 0 || t.chaptersFinished > 0);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Dùng `DateTime(y, m, d - n)` thay vì trừ Duration để không lệch khi đổi
  /// giờ mùa hè.
  static DateTime _minusDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day - n);

  static StatsSummary summarize(List<DailyStat> rows, DateTime now) {
    final today = _dateOnly(now);
    final byDay = <String, StatTotals>{};
    final perBook = <int, StatTotals>{};
    final last30Start = dayKey(_minusDays(today, 29));
    final todayKey = dayKey(today);

    for (final r in rows) {
      final t = StatTotals(
        readSeconds: r.readSeconds,
        listenSeconds: r.listenSeconds,
        chaptersFinished: r.chaptersFinished,
      );
      byDay[r.day] = (byDay[r.day] ?? const StatTotals()) + t;
      if (r.day.compareTo(last30Start) >= 0 && r.day.compareTo(todayKey) <= 0) {
        perBook[r.bookId] = (perBook[r.bookId] ?? const StatTotals()) + t;
      }
    }

    final days = <DayPoint>[];
    var last7 = const StatTotals();
    var last30 = const StatTotals();
    for (var i = 29; i >= 0; i--) {
      final d = _minusDays(today, i);
      final t = byDay[dayKey(d)] ?? const StatTotals();
      days.add(DayPoint(d, t));
      last30 += t;
      if (i < 7) last7 += t;
    }

    // Chuỗi ngày liên tiếp có hoạt động; hôm nay chưa đọc thì tính từ hôm qua.
    var streak = 0;
    var cursor = today;
    if (!_active(byDay[dayKey(cursor)])) {
      cursor = _minusDays(cursor, 1);
    }
    while (_active(byDay[dayKey(cursor)])) {
      streak++;
      cursor = _minusDays(cursor, 1);
    }

    return StatsSummary(
      today: byDay[todayKey] ?? const StatTotals(),
      last7: last7,
      last30: last30,
      days: days,
      streak: streak,
      perBook30: perBook,
    );
  }
}
