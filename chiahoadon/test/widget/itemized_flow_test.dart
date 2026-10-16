import 'package:chiahoadon/core/widgets/member_chip.dart';
import 'package:chiahoadon/core/widgets/money_field.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/detail/bill_detail_screen.dart';
import 'package:chiahoadon/features/bills/form/bill_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Luồng chia theo món (SPEC FR-4.2), kiểm tới tận dữ liệu trong DB.
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late Member an;
  late Member binh;
  late Member chi;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    chi = DbTestHelper.member('Chi');
    for (final member in [an, binh, chi]) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Mở form, đặt tên, chọn đúng ba người An/Bình/Chi, rồi sang bước chia tiền
  /// ở chế độ theo món.
  Future<void> openItemizedForm(WidgetTester tester, String title) async {
    await WidgetTestHelper.pump(
      tester,
      database: database,
      child: const BillFormScreen(),
    );

    await tester.enterText(find.byType(TextField).first, title);
    await WidgetTestHelper.settle(tester);
    await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

    await tester.tap(find.text('Chọn'));
    await WidgetTestHelper.settle(tester);
    for (final name in ['Tôi', 'An', 'Bình', 'Chi']) {
      await tester.tap(find.widgetWithText(MemberChip, name));
    }
    await WidgetTestHelper.settle(tester);
    await tester.tap(find.text('Xong (3)'));
    await WidgetTestHelper.settle(tester);
    await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

    await tester.tap(find.text('Theo món'));
    await WidgetTestHelper.settle(tester);
  }

  /// Thêm một món qua sheet. [exclude] là những người **bỏ chọn** khỏi món
  /// (mặc định sheet chọn sẵn tất cả).
  Future<void> addItem(
    WidgetTester tester, {
    required String name,
    required String price,
    List<String> exclude = const [],
  }) async {
    await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');

    await tester.enterText(find.byType(TextField).first, name);
    await WidgetTestHelper.settle(tester);
    await tester.enterText(find.byType(MoneyField), price);
    await WidgetTestHelper.settle(tester);

    for (final person in exclude) {
      await tester.tap(find.widgetWithText(FilterChip, person));
    }
    await WidgetTestHelper.settle(tester);

    await WidgetTestHelper.tapButton(tester, 'Thêm món');
  }

  group('★ Ví dụ chuẩn của SPEC FR-4.2, đi qua giao diện', () {
    testWidgets(
      'phở + bún chả + trà đá + cà phê → An 90.000 · Bình 65.000 · Chi 60.000',
      (tester) async {
        await openItemizedForm(tester, 'Ăn trưa văn phòng');

        // Giá ghi trên món là giá **một người**.
        await addItem(
          tester,
          name: 'Phở bò',
          price: '60000',
          exclude: ['Chi'],
        );
        await addItem(
          tester,
          name: 'Bún chả',
          price: '55000',
          exclude: ['An', 'Bình'],
        );
        await addItem(tester, name: 'Trà đá', price: '5000');
        await addItem(
          tester,
          name: 'Cà phê',
          price: '25000',
          exclude: ['Bình', 'Chi'],
        );

        expect(find.text('Các món (4)'), findsOneWidget);
        // Tạm tính = 60.000×2 + 55.000 + 5.000×3 + 25.000 = 215.000
        expect(find.textContaining('215.000'), findsAtLeast(1));

        await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');

        final saved = await BillDao(database).getPage(const BillFilter());
        expect(saved, hasLength(1));

        final bill = await BillDao(database).getById(saved.first.id);
        expect(bill!.splitType, SplitType.itemized);
        expect(bill.inputMode, InputMode.items);
        expect(bill.subtotal, 215000);
        expect(bill.totalAmount, 215000);
        expect(bill.items, hasLength(4));

        // Hai người ăn phở thì **mỗi người** trả 60.000 — đây là điều đã sửa
        // so với bản trước, khi tiền món bị đem chia cho số người.
        final pho = bill.items.firstWhere((item) => item.name == 'Phở bò');
        expect(pho.unitPrice, 60000);
        expect(pho.portions, 2);
        expect(pho.amount, 120000);

        final shares = {
          for (final p in bill.participants)
            p.memberNameSnapshot: p.shareAmount,
        };
        expect(shares, {'An': 90000, 'Bình': 65000, 'Chi': 60000});

        // Bất biến cốt lõi, trên dữ liệu đã nằm trong DB.
        expect(bill.totalShares, bill.totalAmount);
        expect(bill.totalShares, 215000);
      },
    );
  });

  group('Danh sách món', () {
    testWidgets('thêm món rồi xóa, tạm tính cập nhật theo', (tester) async {
      await openItemizedForm(tester, 'Ăn trưa');

      // Cơm gà 60.000 × 3 người = 180.000
      await addItem(tester, name: 'Cơm gà', price: '60000');
      expect(find.text('Các món (1)'), findsOneWidget);
      expect(find.textContaining('180.000'), findsAtLeast(1));

      // Thêm trà đá 5.000 × 3 = 15.000 → tạm tính 195.000
      await addItem(tester, name: 'Trà đá', price: '5000');
      expect(find.text('Các món (2)'), findsOneWidget);
      expect(find.textContaining('195.000'), findsAtLeast(1));

      await tester.tap(find.byIcon(Icons.close).last);
      await WidgetTestHelper.settle(tester);

      expect(find.text('Các món (1)'), findsOneWidget);
      expect(find.text('Trà đá'), findsNothing);
    });

    testWidgets('món mặc định chọn sẵn tất cả người tham gia', (tester) async {
      await openItemizedForm(tester, 'Ăn trưa');

      await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');

      expect(find.text('Ai dùng món này? (3)'), findsOneWidget);
    });

    testWidgets('bỏ chọn hết người thì không lưu được món', (tester) async {
      await openItemizedForm(tester, 'Ăn trưa');
      await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');

      await tester.enterText(find.byType(TextField).first, 'Cơm gà');
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField), '60000');
      await WidgetTestHelper.settle(tester);

      for (final person in ['An', 'Bình', 'Chi']) {
        await tester.tap(find.widgetWithText(FilterChip, person));
      }
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('Chọn người dùng món'), findsOneWidget);

      // Số người là một vế của phép nhân, nên không có ai thì không có thành
      // tiền để mà lưu.
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Thêm món'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('tạm tính tăng lên khi thêm người vào món', (tester) async {
      await openItemizedForm(tester, 'Ăn trưa');
      await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');

      await tester.enterText(find.byType(TextField).first, 'Cơm gà');
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField), '60000');
      await WidgetTestHelper.settle(tester);

      // Mặc định cả ba người: 60.000 × 3.
      expect(find.textContaining('× 3 phần'), findsOneWidget);
      expect(find.textContaining('180.000'), findsAtLeast(1));

      await tester.tap(find.widgetWithText(FilterChip, 'Chi'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('× 2 phần'), findsOneWidget);
      expect(find.textContaining('120.000'), findsAtLeast(1));
    });
  });

  group('Trọng số trong món (FR-4.2)', () {
    testWidgets('Bình 2 phần, An 1 phần → Bình trả gấp đôi', (tester) async {
      await openItemizedForm(tester, 'Nhậu');

      await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');
      await tester.enterText(find.byType(TextField).first, 'Bia');
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField), '20000');
      await WidgetTestHelper.settle(tester);

      // Bỏ Chi ra khỏi món
      await tester.tap(find.widgetWithText(FilterChip, 'Chi'));
      await WidgetTestHelper.settle(tester);

      // Mở bảng số phần và tăng của Bình lên 2
      await WidgetTestHelper.tapOutlinedButton(tester, 'Số phần');
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Xong');

      expect(find.textContaining('Bình ×2'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Thêm món');
      await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');

      final saved = await BillDao(database).getPage(const BillFilter());
      final bill = await BillDao(database).getById(saved.first.id);
      final shares = {
        for (final p in bill!.participants)
          p.memberNameSnapshot: p.shareAmount,
      };

      // Giá một lon 20.000: An 1 lon, Bình 2 lon.
      expect(shares['An'], 20000);
      expect(shares['Bình'], 40000);
      expect(shares['Chi'], 0);
      expect(bill.totalShares, 60000);
    });

    testWidgets('chọn riêng một người cho món', (tester) async {
      await openItemizedForm(tester, 'Ăn trưa');

      await WidgetTestHelper.tapOutlinedButton(tester, 'Thêm món');
      await tester.enterText(find.byType(TextField).first, 'Chè');
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField), '20000');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapOutlinedButton(tester, 'Chỉ một người');
      await tester.tap(find.text('Chi').last);
      await WidgetTestHelper.settle(tester);

      expect(find.text('Ai dùng món này? (1)'), findsOneWidget);
    });
  });

  group('S04 — Chi tiết theo món', () {
    testWidgets('hiện từng món và số tiền mỗi người chịu cho món đó', (
      tester,
    ) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 750000,
        participants: [an, binh, chi],
        payer: an,
      ).copyWith(
        splitType: SplitType.itemized,
        inputMode: InputMode.items,
        items: [
          DbTestHelper.item(
            name: 'Lẩu thái',
            unitPrice: 250000,
            users: [an, binh, chi],
          ),
          DbTestHelper.item(
            name: 'Bia Tiger',
            unitPrice: 20000,
            sortOrder: 1,
            users: [an, binh],
          ),
          DbTestHelper.item(
            name: 'Nước ép',
            unitPrice: 50000,
            sortOrder: 2,
            users: [chi],
          ),
        ],
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      expect(find.text('CHI TIẾT THEO MÓN'), findsOneWidget);
      expect(find.textContaining('Lẩu thái'), findsOneWidget);
      expect(find.textContaining('Bia Tiger'), findsOneWidget);

      // Lẩu thái 250.000 một phần, ba người ăn → mỗi người đúng 250.000,
      // không phải chia ba.
      expect(find.text('250.000 đ'), findsAtLeast(3));
      // Nước ép chỉ của Chi
      expect(find.text('50.000 đ'), findsAtLeast(1));
    });
  });
}
