import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/category_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/form/bill_form_screen.dart';
import 'package:chiahoadon/features/bills/list/bills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Tên hóa đơn lấy từ danh mục, và ngày hiển thị trong danh sách.
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late Member an;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

    an = DbTestHelper.member('An');
    await MemberDao(database).insert(an);
  });

  tearDown(() async {
    await database.close();
  });

  /// Tên của danh mục mặc định đầu tiên, dùng để tìm chip trên màn hình.
  Future<String> firstCategoryName() async =>
      (await CategoryDao(database).getAll()).first.name;

  /// Chip của một danh mục.
  ///
  /// Nhãn chip có cả biểu tượng ("🍜 Ăn uống") nên không khớp được bằng tên
  /// trần; tìm theo chuỗi con rồi lần ngược lên chip chứa nó.
  Finder categoryChip(String name) => find.ancestor(
    of: find.textContaining(name),
    matching: find.byType(FilterChip),
  );

  group('Chọn danh mục là có luôn tên hóa đơn', () {
    testWidgets('chạm một danh mục thì tên hóa đơn được điền theo', (
      tester,
    ) async {
      final category = await firstCategoryName();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      // Chưa chọn gì thì ô tên còn trống.
      expect(find.widgetWithText(TextField, category), findsNothing);

      await WidgetTestHelper.tapVisible(
        tester,
        categoryChip(category),
      );

      expect(
        find.widgetWithText(TextField, category),
        findsOneWidget,
        reason: 'Yêu cầu là "khi tạo chỉ cần chọn theo danh mục"',
      );
    });

    testWidgets('đổi sang danh mục khác thì tên đổi theo', (tester) async {
      final categories = await CategoryDao(database).getAll();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await WidgetTestHelper.tapVisible(
        tester,
        categoryChip(categories[0].name),
      );
      await WidgetTestHelper.tapVisible(
        tester,
        categoryChip(categories[1].name),
      );

      expect(
        find.widgetWithText(TextField, categories[1].name),
        findsOneWidget,
      );
    });

    testWidgets('tên tự gõ thì đổi danh mục không xóa mất', (tester) async {
      final categories = await CategoryDao(database).getAll();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await WidgetTestHelper.tapVisible(
        tester,
        categoryChip(categories[0].name),
      );

      // Người dùng sửa lại cho rõ hơn.
      await tester.enterText(
        find.byType(TextField).first,
        'Ăn trưa họp team',
      );
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(
        tester,
        categoryChip(categories[1].name),
      );

      expect(
        find.widgetWithText(TextField, 'Ăn trưa họp team'),
        findsOneWidget,
        reason: 'Đổi danh mục mà xóa tên người dùng tự gõ là mất công của họ',
      );
    });

    testWidgets('bỏ chọn danh mục thì xóa luôn cái tên nó điền', (
      tester,
    ) async {
      final category = await firstCategoryName();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      final chip = categoryChip(category);
      await WidgetTestHelper.tapVisible(tester, chip);
      await WidgetTestHelper.tapVisible(tester, chip);

      expect(
        find.widgetWithText(TextField, category),
        findsNothing,
        reason: 'Để lại tên của danh mục đã bỏ chọn thì hóa đơn mang tên sai',
      );
    });
  });

  group('Danh sách hóa đơn hiện tên và ngày', () {
    testWidgets('ghi đủ ngày tháng năm, không phải "Hôm nay"', (tester) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Ăn lẩu tất niên',
          total: 900000,
          participants: [an],
          payer: an,
          date: DateTime.now(),
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );

      expect(find.text('Ăn lẩu tất niên'), findsOneWidget);
      expect(
        find.textContaining(DateFormatter.short(DateTime.now())),
        findsOneWidget,
        reason: 'Danh sách là chỗ tra lại hóa đơn cũ; "Hôm nay" không đối '
            'chiếu được với gì',
      );
      expect(find.textContaining('Hôm nay'), findsNothing);
    });

    testWidgets('hóa đơn cũ cũng ghi đúng ngày của nó', (tester) async {
      final old = DateTime(2026, 3, 15);
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Tiền nhà tháng 3',
          total: 6000000,
          participants: [an],
          payer: an,
          date: old,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );

      expect(find.textContaining('15/03/2026'), findsOneWidget);
    });
  });
}
