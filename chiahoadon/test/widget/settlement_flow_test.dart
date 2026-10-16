import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/payment_dao.dart';
import 'package:chiahoadon/data/dao/stats_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/detail/bill_detail_screen.dart';
import 'package:chiahoadon/features/settlement/settlement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Thanh toán và quyết toán (SPEC FR-6).
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late Member dung;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

    dung = DbTestHelper.member('Dũng');
    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [dung, an, binh]) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Hóa đơn 900.000 Dũng trả, ba người cùng chịu 300.000.
  Future<Bill> groupBill() async {
    final bill = DbTestHelper.equalBill(
      title: 'Ăn lẩu',
      total: 900000,
      participants: [dung, an, binh],
      payer: dung,
    );
    await BillDao(database).save(bill);
    return bill;
  }

  group('FR-6.1 — Đánh dấu đã trả từng người', () {
    testWidgets('chạm vào một người để chuyển sang đã trả', (tester) async {
      final bill = await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      expect(find.text('chưa trả'), findsNWidgets(2));
      expect(find.text('trả trước cho cả nhóm'), findsOneWidget);

      await WidgetTestHelper.tapVisible(tester, find.text('An'));

      final updated = await BillDao(database).getById(bill.id);
      final anShare = updated!.participantOf(an.id)!;
      expect(anShare.paidAmount, 300000);
      expect(anShare.settledAt, isNotNull);
      expect(updated.status, BillStatus.partial);
    });

    testWidgets('chạm lần nữa để quay về chưa trả', (tester) async {
      final bill = await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      await WidgetTestHelper.tapVisible(tester, find.text('An'));
      await WidgetTestHelper.tapVisible(tester, find.text('An'));

      final updated = await BillDao(database).getById(bill.id);
      expect(updated!.participantOf(an.id)!.paidAmount, 0);
      expect(updated.status, BillStatus.unpaid);
    });

    testWidgets('người trả trước không bấm được, vì họ không nợ ai', (
      tester,
    ) async {
      final bill = await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      // Tên Dũng xuất hiện cả ở thẻ người trả trước lẫn ở danh sách phần
      // mỗi người; lấy dòng trong danh sách.
      await tester.tap(find.text('Dũng').last);
      await WidgetTestHelper.settle(tester);

      final updated = await BillDao(database).getById(bill.id);
      expect(updated!.participantOf(dung.id)!.paidAmount, 0);
      expect(updated.status, BillStatus.unpaid);
    });

    testWidgets('chạm giữ để nhập số tiền trả một phần', (tester) async {
      final bill = await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      await tester.longPress(find.text('An'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('đã trả bao nhiêu'), findsOneWidget);
      expect(find.textContaining('Phải chịu 300.000'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Một nửa'));
      await WidgetTestHelper.settle(tester);
      expect(find.textContaining('Còn thiếu 150.000'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Lưu');

      final updated = await BillDao(database).getById(bill.id);
      expect(updated!.participantOf(an.id)!.paidAmount, 150000);
      expect(updated.status, BillStatus.partial);
    });

    testWidgets('FR-6.3 · nút "Tất cả đã trả" chuyển hóa đơn sang đã xong', (
      tester,
    ) async {
      final bill = await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Tất cả đã trả'),
      );

      final updated = await BillDao(database).getById(bill.id);
      expect(updated!.status, BillStatus.settled);
      expect(
        updated.participants.every((p) => p.paidAmount == p.shareAmount),
        isTrue,
      );
      expect(find.text('Tất cả đã trả'), findsNothing);
    });
  });

  group('S10 — Màn hình quyết toán (FR-6.4, FR-6.5)', () {
    testWidgets('chưa có hóa đơn thì báo không ai nợ ai', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      expect(find.text('Không ai nợ ai'), findsOneWidget);
    });

    testWidgets('hiện số dư ròng và gợi ý đúng 2 giao dịch', (tester) async {
      await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      expect(find.text('SỐ DƯ RÒNG'), findsOneWidget);
      expect(find.text('+600.000 đ'), findsOneWidget);
      expect(find.text('-300.000 đ'), findsNWidgets(2));

      // Ba người lệch nhau → đúng hai giao dịch (SPEC FR-6.5).
      expect(find.textContaining('2 giao dịch là đủ'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đã chuyển'), findsNWidgets(2));
    });

    testWidgets('bấm "Đã chuyển" ghi nhận và đưa số dư về 0', (tester) async {
      await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Đã chuyển').first,
      );
      await WidgetTestHelper.tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Đã chuyển').first,
      );

      final balances = await StatsDao(database).balances();
      expect(balances.every((b) => b.isClear), isTrue);
      expect(balances.fold<int>(0, (sum, b) => sum + b.balance), 0);

      expect(await PaymentDao(database).getAll(), hasLength(2));
    });

    testWidgets('ghi nhận chuyển tiền thủ công (FR-6.6)', (tester) async {
      await groupBill();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      await tester.tap(find.text('Ghi nhận chuyển tiền'));
      await WidgetTestHelper.settle(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'An').first);
      await WidgetTestHelper.settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dũng').last);
      await WidgetTestHelper.settle(tester);

      await tester.enterText(find.byType(TextField).last, '100000');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Ghi nhận');

      final payments = await PaymentDao(database).getAll();
      expect(payments, hasLength(1));
      expect(payments.first.amount, 100000);
      expect(payments.first.fromMemberId, an.id);
      expect(payments.first.toMemberId, dung.id);

      // Số dư của An giảm đi đúng 100.000.
      final balances = await StatsDao(database).balances();
      final anBalance = balances.firstWhere((b) => b.memberId == an.id);
      expect(anBalance.balance, -200000);
    });

    testWidgets('xóa ghi nhận thì số dư quay lại như cũ', (tester) async {
      await groupBill();
      final now = DateTime.now().millisecondsSinceEpoch;
      await PaymentDao(database).insert(
        DbTestHelper.payment(
          from: an,
          to: dung,
          amount: 300000,
          at: now,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      expect(find.text('ĐÃ CHUYỂN'), findsOneWidget);

      await WidgetTestHelper.tapVisible(tester, find.byIcon(Icons.close));
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Xóa');

      expect(await PaymentDao(database).getAll(), isEmpty);

      final balances = await StatsDao(database).balances();
      final anBalance = balances.firstWhere((b) => b.memberId == an.id);
      expect(anBalance.balance, -300000);
    });

    testWidgets('tổng số dư luôn bằng 0 sau mọi thao tác', (tester) async {
      await groupBill();
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Cà phê',
          total: 150000,
          participants: [an, binh],
          payer: an,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const SettlementScreen(),
      );

      // Thực hiện hết mọi giao dịch được gợi ý.
      while (find.widgetWithText(FilledButton, 'Đã chuyển').evaluate().isNotEmpty) {
        await WidgetTestHelper.tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Đã chuyển').first,
        );
      }

      final balances = await StatsDao(database).balances();
      expect(balances.fold<int>(0, (sum, b) => sum + b.balance), 0);
      expect(balances.every((b) => b.isClear), isTrue);
    });
  });
}
