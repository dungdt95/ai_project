enum ReportRange { today, last7Days, last30Days, thisMonth }

extension ReportRangeX on ReportRange {
  String get label {
    switch (this) {
      case ReportRange.today:
        return 'Hôm nay';
      case ReportRange.last7Days:
        return '7 ngày qua';
      case ReportRange.last30Days:
        return '30 ngày qua';
      case ReportRange.thisMonth:
        return 'Tháng này';
    }
  }

  ({DateTime start, DateTime end}) bounds() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportRange.today:
        return (start: todayStart, end: now);
      case ReportRange.last7Days:
        return (start: todayStart.subtract(const Duration(days: 6)), end: now);
      case ReportRange.last30Days:
        return (start: todayStart.subtract(const Duration(days: 29)), end: now);
      case ReportRange.thisMonth:
        return (start: DateTime(now.year, now.month, 1), end: now);
    }
  }
}
