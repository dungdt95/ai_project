import 'package:doctruyen/domain/stats/activity_accumulator.dart';
import 'package:doctruyen/domain/stats/stats_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatsAggregator', () {
    final now = DateTime(2026, 3, 15, 10);

    test('tổng hôm nay / 7 ngày / 30 ngày và chuỗi ngày', () {
      final rows = [
        const DailyStat(
          day: '2026-03-15',
          bookId: 1,
          readSeconds: 600,
          listenSeconds: 60,
          chaptersFinished: 1,
        ),
        const DailyStat(day: '2026-03-15', bookId: 2, readSeconds: 60),
        const DailyStat(day: '2026-03-14', bookId: 1, listenSeconds: 1200),
        const DailyStat(day: '2026-03-13', bookId: 1, readSeconds: 100),
        const DailyStat(
          day: '2026-03-01',
          bookId: 1,
          readSeconds: 1000,
          chaptersFinished: 2,
        ),
        const DailyStat(day: '2026-02-01', bookId: 1, readSeconds: 9999),
      ];
      final s = StatsAggregator.summarize(rows, now);
      expect(s.today.readSeconds, 660);
      expect(s.today.listenSeconds, 60);
      expect(s.today.chaptersFinished, 1);
      expect(s.last7.readSeconds, 760);
      expect(s.last7.listenSeconds, 1260);
      expect(s.last30.readSeconds, 1760);
      expect(s.last30.chaptersFinished, 3);
      expect(s.days.length, 30);
      expect(s.days.last.date, DateTime(2026, 3, 15));
      expect(s.streak, 3);
      expect(s.perBook30[1]!.readSeconds, 1700);
      expect(s.perBook30[2]!.readSeconds, 60);
    });

    test(
      'chuỗi ngày tính từ hôm qua nếu hôm nay chưa đọc; đứt khi cách ngày',
      () {
        final rows = [
          const DailyStat(day: '2026-03-14', bookId: 1, readSeconds: 5),
          const DailyStat(day: '2026-03-13', bookId: 1, readSeconds: 5),
          const DailyStat(day: '2026-03-11', bookId: 1, readSeconds: 5),
        ];
        expect(StatsAggregator.summarize(rows, now).streak, 2);
        expect(StatsAggregator.summarize(const [], now).streak, 0);
      },
    );

    test('chuỗi ngày đi qua ranh giới tháng', () {
      final rows = [
        const DailyStat(day: '2026-03-01', bookId: 1, readSeconds: 5),
        const DailyStat(day: '2026-02-28', bookId: 1, listenSeconds: 5),
      ];
      expect(
        StatsAggregator.summarize(rows, DateTime(2026, 3, 1, 9)).streak,
        2,
      );
    });
  });

  group('ActivityAccumulator', () {
    final t0 = DateTime(2026, 3, 15, 10);

    test('đọc: tính khi có tương tác gần đây, ngừng khi rảnh quá 2 phút', () {
      final a = ActivityAccumulator()
        ..setReading(7, t0)
        ..tick(t0);
      for (var i = 1; i <= 120; i++) {
        a.tick(t0.add(Duration(seconds: i)));
      }
      var d = a.drain();
      expect(d[('2026-03-15', 7)]!.read, 120);
      for (var i = 121; i <= 200; i++) {
        a.tick(t0.add(Duration(seconds: i)));
      }
      expect(a.drain(), isEmpty);
      a.interaction(t0.add(const Duration(seconds: 200)));
      for (var i = 201; i <= 210; i++) {
        a.tick(t0.add(Duration(seconds: i)));
      }
      d = a.drain();
      expect(d[('2026-03-15', 7)]!.read, 10);
    });

    test('nghe tính cả khi rời màn đọc và không cộng đôi giờ đọc', () {
      final a = ActivityAccumulator()
        ..setReading(1, t0)
        ..setListening(1)
        ..tick(t0);
      for (var i = 1; i <= 30; i++) {
        a.tick(t0.add(Duration(seconds: i)));
      }
      var d = a.drain();
      expect(d[('2026-03-15', 1)]!.listen, 30);
      expect(d[('2026-03-15', 1)]!.read, 0);

      a.setReading(null, t0);
      for (var i = 31; i <= 40; i++) {
        a.tick(t0.add(Duration(seconds: i)));
      }
      d = a.drain();
      expect(d[('2026-03-15', 1)]!.listen, 10);
    });

    test('app ở nền không tính giờ đọc; khoảng trống lớn bị cắt', () {
      final a = ActivityAccumulator()
        ..setReading(1, t0)
        ..tick(t0)
        ..appActive = false
        ..tick(t0.add(const Duration(seconds: 5)));
      expect(a.drain(), isEmpty);
      a
        ..appActive = true
        ..interaction(t0.add(const Duration(seconds: 5)))
        ..tick(t0.add(const Duration(seconds: 65)));
      expect(a.drain()[('2026-03-15', 1)]!.read, 10);
    });
  });
}
