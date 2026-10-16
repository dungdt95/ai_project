import 'package:chiahoadon/core/widgets/member_chip.dart';
import 'package:chiahoadon/core/widgets/money_field.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/form/bill_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Phụ phí, giảm giá, làm tròn và các kiểu chia còn lại (SPEC FR-4.3 → FR-5).
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

  /// Mở form, đặt tên, chọn đúng An/Bình/Chi, dừng ở bước chia tiền.
  Future<void> openForm(WidgetTester tester, String title) async {
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
    await WidgetTestHelper.chooseEqualSplit(tester);
  }

  Future<void> openSurchargePanel(WidgetTester tester) async {
    await tester.tap(find.text('Phụ phí & giảm giá'));
    await WidgetTestHelper.settle(tester);
  }

  Future<Bill> savedBill(WidgetTester tester) async {
    await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');
    // Loại nháp: hẹn giờ tự lưu có thể đã ghi một bản nháp trong lúc test gõ.
    final page = await BillDao(database).getPage(
      const BillFilter(includeDrafts: false),
    );
    expect(page, hasLength(1));
    return (await BillDao(database).getById(page.first.id))!;
  }

  group('★ Ví dụ kiểm chứng của SPEC §FR-5, đi qua giao diện', () {
    testWidgets(
      '750.000 chia đều + VAT 8% + phí DV 5%, làm tròn lên 1.000đ',
      (tester) async {
        await openForm(tester, 'Ăn lẩu tất niên');

        await tester.enterText(find.byType(MoneyField).first, '750000');
        await WidgetTestHelper.settle(tester);

        await openSurchargePanel(tester);

        // Ô thứ nhất là tổng tiền, rồi tới giảm giá, VAT, phí dịch vụ, tip.
        final percentFields = find.byType(TextField);
        await tester.enterText(percentFields.at(2), '8');
        await WidgetTestHelper.settle(tester);
        await tester.enterText(percentFields.at(3), '5');
        await WidgetTestHelper.settle(tester);

        final bill = await savedBill(tester);

        expect(bill.subtotal, 750000);
        expect(bill.taxAmount, 60000);
        expect(bill.serviceAmount, 37500);
        expect(bill.totalExact, 847500);
        expect(bill.totalAmount, 848000);
        expect(bill.roundingDelta, 500);
        expect(bill.totalShares, 848000);
      },
    );
  });

  group('★ Ví dụ kiểm chứng đầy đủ: chia theo món + VAT + phí dịch vụ', () {
    testWidgets(
      'phở/bún chả/trà đá/cà phê + VAT 8% + phí DV 5% → 102.000 / 73.000 '
      '/ 68.000',
      (tester) async {
        await openForm(tester, 'Ăn lẩu tất niên');

        await WidgetTestHelper.tapVisible(
          tester,
          find.widgetWithText(ChoiceChip, 'Theo món'),
          insideList: const Key(BillFormScreen.splitStepListKey),
        );

        Future<void> addItem(
          String name,
          String price,
          List<String> exclude,
        ) async {
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

        // Giá ghi trên món là giá một người.
        await addItem('Phở bò', '60000', const ['Chi']);
        await addItem('Bún chả', '55000', const ['An', 'Bình']);
        await addItem('Trà đá', '5000', const []);
        await addItem('Cà phê', '25000', const ['Bình', 'Chi']);

        await WidgetTestHelper.tapVisible(
          tester,
          find.text('Phụ phí & giảm giá'),
          insideList: const Key(BillFormScreen.splitStepListKey),
        );

        // Thứ tự ô nhập trong panel: giảm giá, VAT, phí dịch vụ, tip.
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(1), '8');
        await WidgetTestHelper.settle(tester);
        await tester.enterText(fields.at(2), '5');
        await WidgetTestHelper.settle(tester);

        final bill = await savedBill(tester);

        expect(bill.subtotal, 215000);
        expect(bill.taxAmount, 17200);
        expect(bill.serviceAmount, 10750);
        expect(bill.totalExact, 242950);
        expect(bill.totalAmount, 243000);
        expect(bill.roundingDelta, 50);

        final shares = {
          for (final p in bill.participants)
            p.memberNameSnapshot: p.shareAmount,
        };
        expect(shares, {'An': 102000, 'Bình': 73000, 'Chi': 68000});
        expect(bill.totalShares, 243000);
      },
    );
  });

  group('Phụ phí & giảm giá (FR-5)', () {
    testWidgets('VAT tính sau giảm giá, đúng thứ tự của SPEC', (tester) async {
      await openForm(tester, 'Ăn trưa');

      await tester.enterText(find.byType(MoneyField).first, '750000');
      await WidgetTestHelper.settle(tester);
      await openSurchargePanel(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '10'); // giảm giá 10%
      await WidgetTestHelper.settle(tester);
      await tester.enterText(fields.at(2), '8'); // VAT 8%
      await WidgetTestHelper.settle(tester);

      final bill = await savedBill(tester);

      expect(bill.discountAmount, 75000);
      // VAT 8% của 675.000 (đã trừ giảm giá), không phải của 750.000.
      expect(bill.taxAmount, 54000);
      expect(bill.totalExact, 729000);
      expect(bill.totalShares, bill.totalAmount);
    });

    testWidgets('đổi đơn vị sang số tiền tuyệt đối', (tester) async {
      await openForm(tester, 'Ăn trưa');

      await tester.enterText(find.byType(MoneyField).first, '500000');
      await WidgetTestHelper.settle(tester);
      await openSurchargePanel(tester);

      // Nút "đ" đầu tiên thuộc dòng giảm giá.
      await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'đ').first);
      await WidgetTestHelper.settle(tester);

      await tester.enterText(find.byType(TextField).at(1), '50000');
      await WidgetTestHelper.settle(tester);

      final bill = await savedBill(tester);

      expect(bill.discount.mode, SurchargeMode.amount);
      expect(bill.discountAmount, 50000);
      expect(bill.totalExact, 450000);
    });

    testWidgets('phụ phí chia đều thay vì theo tỷ lệ (FR-5.6)', (
      tester,
    ) async {
      await openForm(tester, 'Ship đồ ăn');

      await tester.enterText(find.byType(MoneyField).first, '300000');
      await WidgetTestHelper.settle(tester);
      await openSurchargePanel(tester);

      // Tip 30.000 chia đều cho 3 người.
      await tester.enterText(find.byType(TextField).at(4), '30000');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(SegmentedButton<SurchargeAlloc>, 'Chia đều'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );

      final bill = await savedBill(tester);

      expect(bill.surchargeAlloc, SurchargeAlloc.equal);
      expect(bill.totalAmount, 330000);
      expect(bill.totalShares, 330000);
      expect(bill.participants.every((p) => p.shareAmount == 110000), isTrue);
    });
  });

  group('Làm tròn (FR-5.7 → FR-5.9)', () {
    testWidgets('đổi đơn vị sang 5.000đ thì mọi phần là bội của 5.000', (
      tester,
    ) async {
      await openForm(tester, 'Ăn lẩu');

      await tester.enterText(find.byType(MoneyField).first, '847500');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, '5.000 đ'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );

      final bill = await savedBill(tester);

      expect(bill.roundingUnit, 5000);
      expect(bill.totalAmount, 850000);
      expect(bill.roundingDelta, 2500);
      expect(
        bill.participants.every((p) => p.shareAmount % 5000 == 0),
        isTrue,
      );
      expect(bill.totalShares, 850000);
    });

    testWidgets('chọn "Không làm tròn" thì giữ nguyên số lẻ', (tester) async {
      await openForm(tester, 'Ăn lẩu');

      await tester.enterText(find.byType(MoneyField).first, '847500');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, 'Không làm tròn'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );

      final bill = await savedBill(tester);

      expect(bill.totalAmount, 847500);
      expect(bill.roundingDelta, 0);
      expect(bill.totalShares, 847500);
    });

    testWidgets('chênh lệch do làm tròn được nói rõ trên màn hình (FR-5.9)', (
      tester,
    ) async {
      await openForm(tester, 'Ăn lẩu');

      await tester.enterText(find.byType(MoneyField).first, '847500');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.scrollTo(
        tester,
        find.textContaining('đã được làm tròn thành'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );
      expect(find.textContaining('đã được làm tròn thành'), findsOneWidget);

      await WidgetTestHelper.scrollTo(
        tester,
        find.textContaining('Đã làm tròn'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );
      expect(find.textContaining('Đã làm tròn'), findsOneWidget);
    });
  });

  group('Chia theo phần trăm (FR-4.3)', () {
    testWidgets('nhập 50/30/20 rồi lưu', (tester) async {
      await openForm(tester, 'Thuê xe');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo %'));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField).first, '1000000');
      await WidgetTestHelper.settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '50');
      await tester.enterText(fields.at(1), '30');
      await tester.enterText(fields.at(2), '20');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Đủ 100%'), findsOneWidget);

      final bill = await savedBill(tester);
      final shares = {
        for (final p in bill.participants) p.memberNameSnapshot: p.shareAmount,
      };

      expect(shares, {'An': 500000, 'Bình': 300000, 'Chi': 200000});
      expect(bill.totalShares, 1000000);
    });

    testWidgets('thiếu % thì báo rõ còn thiếu bao nhiêu và chặn lưu', (
      tester,
    ) async {
      await openForm(tester, 'Thuê xe');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo %'));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField).first, '1000000');
      await WidgetTestHelper.settle(tester);

      await tester.enterText(find.byType(TextFormField).at(0), '50');
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('Còn thiếu 50%'), findsOneWidget);

      await WidgetTestHelper.scrollTo(
        tester,
        find.text("Chưa chia được"),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );
      expect(find.text('Chưa chia được'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');
      expect(
        await BillDao(database).count(const BillFilter(includeDrafts: false)),
        0,
      );
    });

    testWidgets('nút "Chia đều" đặt 100% chia hết cho số người', (
      tester,
    ) async {
      await openForm(tester, 'Thuê xe');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo %'));
      await WidgetTestHelper.settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Chia đều'));
      await WidgetTestHelper.settle(tester);

      expect(find.text('Đủ 100%'), findsOneWidget);
    });
  });

  group('Chia theo số phần (FR-4.4)', () {
    testWidgets('tiền nhà 6.000.000, An 2 phần → An 3.000.000', (
      tester,
    ) async {
      await openForm(tester, 'Tiền nhà');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo số phần'));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField).first, '6000000');
      await WidgetTestHelper.settle(tester);

      // Tăng số phần của An lên 2.
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await WidgetTestHelper.settle(tester);

      final bill = await savedBill(tester);
      final shares = {
        for (final p in bill.participants) p.memberNameSnapshot: p.shareAmount,
      };

      expect(shares, {'An': 3000000, 'Bình': 1500000, 'Chi': 1500000});
      expect(bill.totalShares, 6000000);
    });
  });

  group('Chia theo số tiền chỉ định (FR-4.5)', () {
    testWidgets('hiện số còn lại chưa phân bổ và chặn khi chưa khớp', (
      tester,
    ) async {
      await openForm(tester, 'Mua chung');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Số tiền cụ thể'));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField).first, '500000');
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('Còn 500.000 đ chưa phân bổ'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '200000');
      await tester.enterText(find.byType(TextFormField).at(1), '180000');
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('Còn 120.000 đ'), findsOneWidget);

      // Dồn phần dư cho người cuối.
      await tester.tap(find.widgetWithText(TextButton, 'Dồn phần dư'));
      await WidgetTestHelper.settle(tester);
      expect(find.textContaining('Đã phân bổ đủ'), findsOneWidget);

      final bill = await savedBill(tester);
      final shares = {
        for (final p in bill.participants) p.memberNameSnapshot: p.shareAmount,
      };

      expect(shares, {'An': 200000, 'Bình': 180000, 'Chi': 120000});
      expect(bill.totalShares, 500000);
    });
  });

  group('Đổi kiểu chia (SPEC FR-4, quy tắc chuyển đổi)', () {
    testWidgets('hỏi xác nhận khi việc đổi làm mất số đã nhập', (tester) async {
      await openForm(tester, 'Mua chung');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Số tiền cụ thể'));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(MoneyField).first, '500000');
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '500000');
      await WidgetTestHelper.settle(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Chia đều'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('sẽ không còn được dùng'), findsOneWidget);

      // Hủy thì giữ nguyên kiểu chia cũ.
      await tester.tap(find.text('Hủy'));
      await WidgetTestHelper.settle(tester);
      expect(find.textContaining('Đã phân bổ đủ'), findsOneWidget);
    });

    testWidgets('chưa nhập gì thì đổi kiểu chia không hỏi', (tester) async {
      await openForm(tester, 'Ăn trưa');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo %'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('sẽ không còn được dùng'), findsNothing);
      expect(find.text('Tỷ lệ từng người'), findsOneWidget);
    });
  });
}
