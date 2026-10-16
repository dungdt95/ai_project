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
import 'package:chiahoadon/features/bills/list/bills_screen.dart';
import 'package:chiahoadon/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

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

  group('S02 — Danh sách hóa đơn', () {
    testWidgets('chưa có hóa đơn thì hiện trạng thái trống có nút tạo', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );

      expect(find.text('Chưa có hóa đơn nào'), findsOneWidget);
      expect(find.text('Tạo hóa đơn'), findsAtLeast(1));
    });

    testWidgets('hiện tên, tổng tiền, số người và trạng thái', (tester) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Ăn lẩu tất niên',
          total: 900000,
          participants: [an, binh, chi],
          payer: an,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );

      expect(find.text('Ăn lẩu tất niên'), findsOneWidget);
      expect(find.text('900.000 đ'), findsOneWidget);
      expect(find.textContaining('3 người'), findsOneWidget);
      expect(find.text('Chưa thanh toán'), findsAtLeast(1));
    });

    testWidgets('tìm kiếm bỏ dấu: gõ "an lau" ra "Ăn lẩu"', (tester) async {
      final billDao = BillDao(database);
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Ăn lẩu tất niên',
          total: 900000,
          participants: [an],
          payer: an,
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Cà phê sáng',
          total: 50000,
          participants: [an],
          payer: an,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );
      expect(find.text('Cà phê sáng'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(TextField).first, 'an lau');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Ăn lẩu tất niên'), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsNothing);
    });

    testWidgets('lọc theo trạng thái', (tester) async {
      final billDao = BillDao(database);
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn còn nợ',
          total: 100000,
          participants: [an, binh],
          payer: an,
        ),
      );
      final settled = DbTestHelper.equalBill(
        title: 'Hóa đơn đã trả hết',
        total: 200000,
        participants: [an, binh],
        payer: an,
      );
      await billDao.save(settled);
      await billDao.settleAll(settled.id);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );
      expect(find.text('Hóa đơn còn nợ'), findsOneWidget);

      // Thanh lọc cuộn ngang; nút trạng thái nằm sau các nút thời gian nên
      // phải kéo tới mới bấm được trên màn hình hẹp.
      final chip = find.widgetWithText(FilterChip, 'Đã xong');
      await tester.dragUntilVisible(
        chip,
        find.byKey(const Key(BillsScreen.filterBarKey)),
        const Offset(-200, 0),
      );
      await WidgetTestHelper.settle(tester);
      await tester.tap(chip);
      await WidgetTestHelper.settle(tester);

      expect(find.text('Hóa đơn đã trả hết'), findsOneWidget);
      expect(find.text('Hóa đơn còn nợ'), findsNothing);
    });
  });

  group('S03 — Luồng tạo hóa đơn chia đều', () {
    testWidgets('đi hết ba bước rồi lưu, số tiền khớp tuyệt đối', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      // Bước 1 — tên hóa đơn
      expect(find.text('Tạo hóa đơn'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Ăn lẩu tất niên');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

      // Bước 2 — chọn người tham gia.
      // "Tôi" được chọn sẵn; bỏ chọn để còn đúng ba người, qua đó kiểm tra
      // luôn thao tác bỏ chọn.
      await tester.tap(find.text('Chọn'));
      await WidgetTestHelper.settle(tester);
      for (final name in ['Tôi', 'An', 'Bình', 'Chi']) {
        await tester.tap(find.widgetWithText(MemberChip, name));
      }
      await WidgetTestHelper.settle(tester);
      expect(find.text('Đã chọn 3'), findsOneWidget);

      await tester.tap(find.text('Xong (3)'));
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.chooseEqualSplit(tester);

      // Bước 3 — nhập tổng tiền, khung xem trước cập nhật ngay
      await tester.enterText(find.byType(MoneyField), '1000000');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.scrollTo(
        tester,
        find.text('XEM TRƯỚC'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );
      expect(find.text('XEM TRƯỚC'), findsOneWidget);
      expect(find.text('334.000 đ'), findsOneWidget);
      expect(find.text('333.000 đ'), findsNWidgets(2));

      await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');

      final saved = await BillDao(database).getPage(const BillFilter());
      expect(saved, hasLength(1));
      expect(saved.first.title, 'Ăn lẩu tất niên');
      expect(saved.first.totalAmount, 1000000);
      // Bất biến cốt lõi, kiểm tra trên dữ liệu đã nằm trong DB.
      expect(saved.first.totalShares, 1000000);
      expect(saved.first.participants, hasLength(3));
      // "Tôi" đã bị bỏ khỏi danh sách tham gia nhưng vẫn là người ứng tiền.
      expect(saved.first.payers, hasLength(1));
      expect(saved.first.totalPaidByPayers, 1000000);
    });

    testWidgets('mở màn tạo hóa đơn: chia theo món đứng đầu và là mặc định', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await tester.enterText(find.byType(TextField).first, 'Ăn trưa');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

      // Chỉ lấy các nút kiểu chia: trên màn này còn có ChoiceChip khác (đơn vị
      // làm tròn…) không thuộc dãy cần kiểm.
      final splitLabels = SplitType.values.map((type) => type.label).toSet();
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((chip) => splitLabels.contains((chip.label as Text).data))
          .toList();

      // Thứ tự các nút: theo món đứng trước chia đều.
      final labels = chips.map((chip) => (chip.label as Text).data).toList();
      expect(labels.first, 'Theo món');
      expect(
        labels.indexOf('Theo món'),
        lessThan(labels.indexOf('Chia đều')),
      );

      // Và là cái đang được chọn, không cần chạm gì.
      expect(chips.first.selected, isTrue);
      expect(chips.where((chip) => chip.selected), hasLength(1));

      // Chưa có ô nhập tổng tiền nào: chế độ nhập là danh sách món.
      expect(find.byType(MoneyField), findsNothing);
      expect(find.text('Thêm món'), findsWidgets);
    });

    testWidgets('khung xem trước cập nhật ngay theo từng ký tự gõ', (
      tester,
    ) async {
      // Khung cao để ô nhập tiền và khung xem trước cùng nằm trên màn hình —
      // test này kiểm **nội dung cập nhật tức thì**, không kiểm bố cục, nên
      // không nên vướng vào chuyện cuộn qua lại.
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await tester.enterText(find.byType(TextField).first, 'Ăn trưa');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.chooseEqualSplit(tester);

      await tester.enterText(find.byType(MoneyField), '100000');
      await WidgetTestHelper.settle(tester);
      expect(find.text('XEM TRƯỚC'), findsOneWidget);
      expect(find.text('100.000 đ'), findsAtLeast(1));

      // Gõ thêm một chữ số: kết quả phải đổi ngay, không cần bấm nút nào.
      await tester.enterText(find.byType(MoneyField), '1000000');
      await WidgetTestHelper.settle(tester);
      expect(find.text('1.000.000 đ'), findsAtLeast(1));
    });

    testWidgets('thiếu tên thì nút lưu nói rõ lý do và không ghi gì', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');
      await WidgetTestHelper.chooseEqualSplit(tester);
      await tester.enterText(find.byType(MoneyField), '100000');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Hóa đơn cần có tên'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Tạo hóa đơn');
      expect(await BillDao(database).count(const BillFilter()), 0);
    });

    testWidgets('bỏ hết người tham gia thì khung xem trước báo lỗi', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await tester.enterText(find.byType(TextField).first, 'Ăn trưa');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

      // Bỏ "Tôi" ra khỏi danh sách.
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Tiếp tục');

      await WidgetTestHelper.scrollTo(
        tester,
        find.text('Chưa chia được'),
        insideList: const Key(BillFormScreen.splitStepListKey),
      );
      expect(find.text('Chưa chia được'), findsOneWidget);
      expect(find.textContaining('ít nhất một người'), findsAtLeast(1));
    });
  });

  group('S04 — Chi tiết hóa đơn', () {
    testWidgets('hiện tổng, người trả trước và phần mỗi người', (tester) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 900000,
        participants: [an, binh, chi],
        payer: an,
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      expect(find.text('Ăn lẩu'), findsOneWidget);
      expect(find.text('900.000 đ'), findsAtLeast(1));
      expect(find.text('Người trả trước'), findsOneWidget);
      expect(find.text('PHẦN MỖI NGƯỜI'), findsOneWidget);
      expect(find.text('300.000 đ'), findsNWidgets(3));
    });

    testWidgets('không còn dòng nhắc "sẽ có ở Phase N" của giai đoạn dựng app', (
      tester,
    ) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 900000,
        participants: [an, binh, chi],
        payer: an,
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
        size: WidgetTestHelper.tallViewport,
      );

      // Chia sẻ đã có từ Phase 9; dòng báo "sẽ có" còn sót lại là nói dối người
      // dùng về chính tính năng đang nằm ngay trên thanh tiêu đề.
      expect(find.textContaining('Phase'), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('nhân bản tạo hóa đơn mới, hóa đơn gốc giữ nguyên', (
      tester,
    ) async {
      final bill = DbTestHelper.equalBill(
        title: 'Tiền nhà',
        total: 6000000,
        participants: [an, binh],
        payer: an,
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillDetailScreen(billId: bill.id),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await WidgetTestHelper.settle(tester);
      await tester.tap(find.text('Nhân bản'));
      await WidgetTestHelper.settle(tester);

      final all = await BillDao(database).getPage(const BillFilter());
      expect(all, hasLength(2));
      expect(all.every((b) => b.title == 'Tiền nhà'), isTrue);
      expect(all.map((b) => b.id).toSet(), hasLength(2));
      // Bản sao là khoản chi mới nên chưa ai trả.
      expect(
        all.every((b) => b.totalShares == b.totalAmount),
        isTrue,
      );
    });

    testWidgets('xóa có xác nhận, và hoàn tác được', (tester) async {
      final bill = DbTestHelper.equalBill(
        title: 'Cà phê',
        total: 60000,
        participants: [an],
        payer: an,
      );
      await BillDao(database).save(bill);

      // Đi từ danh sách vào chi tiết, đúng như người dùng thật: sau khi xóa,
      // màn chi tiết đóng lại và SnackBar hoàn tác hiện trên danh sách.
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );
      await tester.tap(find.text('Cà phê'));
      await WidgetTestHelper.settle(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await WidgetTestHelper.settle(tester);
      await tester.tap(find.text('Xóa'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('hoàn tác'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await WidgetTestHelper.settle(tester);

      expect(await BillDao(database).count(const BillFilter()), 0);

      await tester.tap(find.text('Hoàn tác'));
      await WidgetTestHelper.settle(tester);

      expect(await BillDao(database).count(const BillFilter()), 1);
    });
  });

  group('FR-3.13 — Sửa hóa đơn tính lại phần chia', () {
    testWidgets('đổi tổng tiền thì phần mọi người đổi theo, tổng vẫn khớp', (
      tester,
    ) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn trưa',
        total: 300000,
        participants: [an, binh, chi],
        payer: an,
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: BillFormScreen(bill: bill),
      );

      // Sửa hóa đơn mở thẳng bước cuối.
      expect(find.text('Sửa hóa đơn'), findsOneWidget);

      await tester.enterText(find.byType(MoneyField), '900000');
      await WidgetTestHelper.settle(tester);
      await WidgetTestHelper.tapButton(tester, 'Lưu thay đổi');

      final updated = await BillDao(database).getById(bill.id);
      expect(updated!.totalAmount, 900000);
      expect(updated.totalShares, 900000);
      expect(updated.participantOf(an.id)!.shareAmount, 300000);
      // Vẫn là một hóa đơn, không tạo thêm bản ghi.
      expect(await BillDao(database).count(const BillFilter()), 1);
    });
  });

  group('Nháp tự lưu (NFR-10)', () {
    testWidgets('bỏ dở hóa đơn thì nháp được giữ lại', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillFormScreen(),
      );

      await tester.enterText(find.byType(TextField).first, 'Hóa đơn dở dang');
      await WidgetTestHelper.settle(tester);

      // Chờ qua mốc tự lưu nháp.
      await tester.pump(const Duration(seconds: 4));
      await WidgetTestHelper.settle(tester);

      final drafts = await BillDao(database).getDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Hóa đơn dở dang');
      expect(drafts.first.status, BillStatus.draft);

      // Nháp không được tính vào danh sách chính.
      final visible = await BillDao(database).getPage(
        const BillFilter(includeDrafts: false),
      );
      expect(visible, isEmpty);
    });

    testWidgets('chạm vào nháp thì mở lại form để nhập tiếp, không mở màn xem', (
      tester,
    ) async {
      final draft = DbTestHelper.equalBill(
        title: 'Hóa đơn dở dang',
        total: 0,
        participants: [an],
        payer: an,
        status: BillStatus.draft,
      );
      await BillDao(database).save(draft);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const BillsScreen(),
      );

      await WidgetTestHelper.tapVisible(tester, find.text('Hóa đơn dở dang'));

      // Mở màn xem chi tiết thì nháp thành ngõ cụt: không có đường nào quay
      // lại hoàn tất nó.
      expect(find.byType(BillFormScreen), findsOneWidget);
      expect(find.byType(BillDetailScreen), findsNothing);

      // Và mở lại từ bước đầu, vì nháp thường còn thiếu cả tên lẫn người.
      expect(find.text('Tiếp tục nháp'), findsOneWidget);
      expect(find.text('Tên hóa đơn *'), findsOneWidget);
    });

    testWidgets('nháp không nằm trong "Hóa đơn gần đây" ở trang chủ', (
      tester,
    ) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn dở dang',
          total: 0,
          participants: [an],
          payer: an,
          status: BillStatus.draft,
        ),
      );
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [an, binh],
          payer: an,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const HomeScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('Ăn trưa'), findsOneWidget);
      expect(
        find.text('Hóa đơn dở dang'),
        findsNothing,
        reason: 'Nháp chưa có số tiền, để chung với hóa đơn đã chốt thì gây '
            'hiểu nhầm',
      );
    });
  });
}
