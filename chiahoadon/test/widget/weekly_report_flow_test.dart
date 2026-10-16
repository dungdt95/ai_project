import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/members/member_detail_screen.dart';
import 'package:chiahoadon/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Báo cáo theo tuần và việc hiện rõ kỳ đang xem.
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

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

  group('Chọn kỳ theo tuần', () {
    testWidgets('có chip "Tuần này" và "Tuần trước"', (tester) async {
      await addBill(DateTime.now(), 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('Tuần này'), findsOneWidget);
      expect(find.text('Tuần trước'), findsOneWidget);
    });

    testWidgets('hiện rõ kỳ đang xem là từ ngày nào tới ngày nào', (
      tester,
    ) async {
      await addBill(DateTime.now(), 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // Mặc định là "Tháng này" — gọi theo tên tháng.
      expect(
        find.text(DateFormatter.monthYear(DateTime.now())),
        findsOneWidget,
      );

      await tester.tap(find.text('Tuần này'));
      await WidgetTestHelper.settle(tester);

      expect(
        find.text(DateRange.thisWeek().detail),
        findsOneWidget,
        reason: 'Chỉ ghi "Tuần này" thì người đọc phải tự đếm lùi',
      );
    });

    testWidgets('lọc đúng theo tuần: hóa đơn tuần trước không tính vào', (
      tester,
    ) async {
      final thisWeek = DateFormatter.startOfWeek(DateTime.now());

      await addBill(thisWeek, 300000);
      await addBill(thisWeek.subtract(const Duration(days: 3)), 900000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await tester.tap(find.text('Tuần này'));
      await WidgetTestHelper.settle(tester);

      expect(find.text('300.000 đ'), findsWidgets);
      expect(
        find.text('1.200.000 đ'),
        findsNothing,
        reason: 'Tổng của cả hai tuần là 1.200.000 — lọt vào là lọc sai',
      );
    });

    testWidgets('màn chi tiết thành viên cũng nói rõ kỳ', (tester) async {
      await addBill(DateTime.now(), 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
        size: WidgetTestHelper.tallViewport,
      );

      // Mặc định của màn này là "Tất cả".
      expect(find.text('Toàn bộ thời gian'), findsOneWidget);

      await tester.tap(find.text('Tuần này'));
      await WidgetTestHelper.settle(tester);

      expect(find.text(DateRange.thisWeek().detail), findsOneWidget);
    });
  });

  group('Biểu đồ xu hướng đổi được giữa tuần và tháng', () {
    testWidgets('mặc định gộp theo tháng', (tester) async {
      await addBill(DateTime.now(), 300000);
      await addBill(
        DateTime.now().subtract(const Duration(days: 40)),
        500000,
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('TỔNG CHI THEO THÁNG'), findsOneWidget);
    });

    testWidgets('chuyển sang tuần thì đổi cả tiêu đề lẫn dữ liệu', (
      tester,
    ) async {
      final thisWeek = DateFormatter.startOfWeek(DateTime.now());

      await addBill(thisWeek, 300000);
      await addBill(thisWeek.subtract(const Duration(days: 7)), 500000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // Hai tuần này nằm ở tháng trước, nên phải mở rộng kỳ ra mới thấy.
      // Chip "Tất cả" nằm cuối thanh chọn kỳ, phải cuộn ngang mới tới.
      await WidgetTestHelper.tapVisible(
        tester,
        find.text('Tất cả'),
        insideList: const Key(StatsScreen.periodBarKey),
      );

      await WidgetTestHelper.tapVisible(tester, find.text('Tuần'));

      expect(find.text('TỔNG CHI THEO TUẦN'), findsOneWidget);
      expect(find.text('TỔNG CHI THEO THÁNG'), findsNothing);
    });

    testWidgets('chỉ có một kỳ thì nói rõ vì sao chưa vẽ biểu đồ', (
      tester,
    ) async {
      await addBill(DateTime.now(), 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(
        find.textContaining('ít nhất hai tháng'),
        findsOneWidget,
        reason: 'Để trống một khoảng thì người dùng tưởng app lỗi',
      );

      await WidgetTestHelper.tapVisible(tester, find.text('Tuần'));
      expect(find.textContaining('ít nhất hai tuần'), findsOneWidget);
    });
  });
}
