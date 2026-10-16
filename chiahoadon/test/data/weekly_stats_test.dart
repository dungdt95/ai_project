import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/stats_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

/// Báo cáo theo tuần.
///
/// Tuần ở Việt Nam bắt đầu từ thứ Hai. Nhóm sai một ngày là mọi con số của tuần
/// lệch đi mà không có gì báo lỗi, nên các mốc đầu/cuối tuần được kiểm riêng.
void main() {
  setUpAll(DbTestHelper.initFfi);

  group('Mốc đầu và cuối tuần', () {
    // Thứ Năm 01/10/2026. Tuần chứa nó là 28/09 (thứ Hai) → 04/10 (Chủ nhật).
    final thursday = DateTime(2026, 10, 1, 15, 30);

    test('đầu tuần là thứ Hai lúc 00:00', () {
      final start = DateFormatter.startOfWeek(thursday);

      expect(start, DateTime(2026, 9, 28));
      expect(start.weekday, DateTime.monday);
    });

    test('cuối tuần là Chủ nhật lúc 23:59:59.999', () {
      final end = DateFormatter.endOfWeek(thursday);

      expect(end.year, 2026);
      expect(end.month, 10);
      expect(end.day, 4);
      expect(end.weekday, DateTime.sunday);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });

    test('đang là thứ Hai thì đầu tuần là chính ngày đó', () {
      final monday = DateTime(2026, 9, 28, 9);

      expect(DateFormatter.startOfWeek(monday), DateTime(2026, 9, 28));
    });

    test('đang là Chủ nhật thì vẫn thuộc tuần bắt đầu từ thứ Hai trước đó', () {
      final sunday = DateTime(2026, 10, 4, 22);

      expect(
        DateFormatter.startOfWeek(sunday),
        DateTime(2026, 9, 28),
        reason: 'Chủ nhật là ngày cuối tuần, không phải ngày đầu',
      );
    });

    test('tuần bắc qua hai tháng vẫn liền mạch', () {
      // Tuần 28/09 → 04/10 nằm vắt qua tháng.
      final range = DateRange.thisWeek(DateTime(2026, 10, 1));

      expect(range.from.month, 9);
      expect(range.to.month, 10);
    });

    test('tuần bắc qua hai năm vẫn liền mạch', () {
      // 01/01/2027 là thứ Sáu; tuần của nó bắt đầu 28/12/2026.
      final range = DateRange.thisWeek(DateTime(2027, 1, 1));

      expect(range.from, DateTime(2026, 12, 28));
      expect(range.to.year, 2027);
    });
  });

  group('Nhãn kỳ nói rõ từ ngày nào tới ngày nào', () {
    test('tuần hiện khoảng ngày', () {
      final range = DateRange.thisWeek(DateTime(2026, 10, 1));

      expect(range.label, 'Tuần này');
      expect(range.detail, '28/09 – 04/10/2026');
    });

    test('tuần trước lùi đúng bảy ngày', () {
      final range = DateRange.lastWeek(DateTime(2026, 10, 1));

      expect(range.from, DateTime(2026, 9, 21));
      expect(range.detail, '21/09 – 27/09/2026');
    });

    test('tháng gọi theo tên tháng, không in khoảng ngày', () {
      expect(DateRange.thisMonth(DateTime(2026, 10, 15)).detail, 'Tháng 10/2026');
      expect(DateRange.lastMonth(DateTime(2026, 10, 15)).detail, 'Tháng 9/2026');
    });

    test('năm gọi theo năm', () {
      expect(DateRange.thisYear(DateTime(2026, 5, 5)).detail, 'Năm 2026');
    });

    test('"tất cả" không in hai mốc kỹ thuật ra màn hình', () {
      expect(DateRange.allTime().detail, 'Toàn bộ thời gian');
    });

    test('3 tháng in khoảng ngày thật', () {
      expect(
        DateRange.last3Months(DateTime(2026, 10, 15)).detail,
        '01/08 – 31/10/2026',
      );
    });

    test('khoảng vắt qua hai năm thì ghi đủ năm ở cả hai đầu', () {
      expect(
        DateFormatter.span(DateTime(2026, 12, 28), DateTime(2027, 1, 3)),
        '28/12/2026 – 03/01/2027',
      );
    });
  });

  group('Tổng chi theo tuần', () {
    late AppDatabase database;
    late StatsDao stats;
    late Member an;
    late Member binh;

    setUp(() async {
      database = await DbTestHelper.openDb();
      stats = StatsDao(database);

      an = DbTestHelper.member('An');
      binh = DbTestHelper.member('Bình');
      for (final member in [an, binh]) {
        await MemberDao(database).insert(member);
      }
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> addBill(DateTime date, int total) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: total,
          participants: [an, binh],
          payer: an,
          date: date,
        ),
      );
    }

    test('gộp các hóa đơn cùng tuần vào một dòng', () async {
      // Cả ba nằm trong tuần 28/09 → 04/10.
      await addBill(DateTime(2026, 9, 28), 100000); // thứ Hai
      await addBill(DateTime(2026, 10, 1), 200000); // thứ Năm
      await addBill(DateTime(2026, 10, 4), 300000); // Chủ nhật

      final weeks = await stats.weeklyTotals();

      expect(weeks, hasLength(1));
      expect(weeks.first.weekStart, '2026-09-28');
      expect(weeks.first.total, 600000);
      expect(weeks.first.billCount, 3);
    });

    test('tách hai tuần liền kề', () async {
      await addBill(DateTime(2026, 9, 27), 100000); // Chủ nhật tuần trước
      await addBill(DateTime(2026, 9, 28), 200000); // thứ Hai tuần sau

      final weeks = await stats.weeklyTotals();

      expect(weeks, hasLength(2));
      expect(
        [for (final week in weeks) week.weekStart],
        ['2026-09-28', '2026-09-21'],
        reason: 'Tuần mới nhất đứng trước',
      );
    });

    test('mốc đầu tuần trong SQL khớp với mốc tính bằng Dart', () async {
      // Hai cách tính nằm ở hai nơi (SQLite và Dart). Lệch nhau thì biểu đồ và
      // bộ lọc kỳ sẽ nói hai điều khác nhau về cùng một tuần.
      for (final day in [
        DateTime(2026, 9, 28), // thứ Hai
        DateTime(2026, 9, 30), // thứ Tư
        DateTime(2026, 10, 4), // Chủ nhật
        DateTime(2027, 1, 1), // vắt qua năm
      ]) {
        await addBill(day, 50000);
      }

      final weeks = await stats.weeklyTotals();
      for (final week in weeks) {
        expect(
          week.start,
          DateFormatter.startOfWeek(week.start),
          reason: '${week.weekStart} không phải thứ Hai',
        );
      }
    });

    test('trả về khoảng ngày đọc được cho từng tuần', () async {
      await addBill(DateTime(2026, 10, 1), 100000);

      final week = (await stats.weeklyTotals()).first;

      expect(week.label, '28/09');
      expect(week.rangeLabel, '28/09 – 04/10/2026');
    });

    test('giới hạn số tuần trả về', () async {
      for (var i = 0; i < 20; i++) {
        await addBill(DateTime(2026, 10, 1).subtract(Duration(days: i * 7)), 1000);
      }

      expect(await stats.weeklyTotals(weeks: 12), hasLength(12));
    });

    test('chưa có hóa đơn nào thì trả danh sách rỗng', () async {
      expect(await stats.weeklyTotals(), isEmpty);
    });
  });
}
