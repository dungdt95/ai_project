import 'package:chiahoadon/core/widgets/payment_qr_block.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/category_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/expense_category.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/home/home_screen.dart';
import 'package:chiahoadon/features/members/member_detail_screen.dart';
import 'package:chiahoadon/features/stats/report_share_screen.dart';
import 'package:chiahoadon/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Thống kê và dashboard (SPEC FR-7).
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late Member self;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

    self = (await MemberDao(database).getSelf())!;
    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [an, binh]) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Dựng [count] hóa đơn giống nhau trong tháng này.
  ///
  /// Mỗi hóa đơn [amount] đồng chia đều cho ba người, nên tổng của mỗi người
  /// là `count × amount / 3` — số tính tay để đối chiếu với biểu đồ.
  Future<void> seedBills({required int count, required int amount}) async {
    for (var i = 0; i < count; i++) {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn ${i + 1}',
          total: amount,
          participants: [self, an, binh],
          payer: self,
          date: DateTime.now(),
        ),
      );
    }
  }

  group('S11 — Thống kê (FR-7.1, FR-7.4)', () {
    testWidgets('chưa có hóa đơn thì báo chưa có số liệu', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
      );

      expect(find.text('Chưa có số liệu'), findsOneWidget);
    });

    testWidgets('★ 20 hóa đơn mẫu: số trên màn hình bằng số tính tay', (
      tester,
    ) async {
      // 20 hóa đơn × 300.000, chia đều 3 người → mỗi người 100.000/hóa đơn.
      await seedBills(count: 20, amount: 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // Tổng cả nhóm = 20 × 300.000. Xuất hiện hai lần: ô tổng ở đầu màn
      // hình và dòng "Chưa phân loại" ở mục danh mục.
      expect(find.text('6.000.000 đ'), findsNWidgets(2));

      // Mỗi người = 20 × 100.000, và xuất hiện ở ba chỗ: bảng xếp hạng, chú
      // giải biểu đồ tròn, và khối "từng thành viên theo danh mục".
      expect(find.text('2.000.000 đ'), findsNWidgets(9));

      // Mỗi người tham gia đủ 20 hóa đơn, trung bình 100.000 một lần.
      expect(
        find.textContaining('20 hóa đơn · trung bình 100.000 đ'),
        findsNWidgets(3),
      );

      // Ba người chia đều nên mỗi người chiếm 33%.
      expect(find.text('33%'), findsNWidgets(3));
    });

    testWidgets('xếp hạng giảm dần theo tổng chi', (tester) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Chỉ An',
          total: 900000,
          participants: [an],
          payer: an,
        ),
      );
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Chỉ Bình',
          total: 100000,
          participants: [binh],
          payer: binh,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // Tên xuất hiện cả ở bảng xếp hạng lẫn ở chú giải biểu đồ tròn; lấy
      // lần xuất hiện đầu, tức dòng trong bảng xếp hạng.
      final anY = tester.getTopLeft(find.text('An').first).dy;
      final binhY = tester.getTopLeft(find.text('Bình').first).dy;
      expect(anY, lessThan(binhY), reason: 'An chi nhiều hơn nên đứng trên');
    });

    testWidgets('đổi kỳ thống kê thì số liệu đổi theo (FR-7.3)', (
      tester,
    ) async {
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Tháng này',
          total: 300000,
          participants: [an],
          payer: an,
          date: DateTime.now(),
        ),
      );
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Năm ngoái',
          total: 900000,
          participants: [an],
          payer: an,
          date: DateTime(DateTime.now().year - 1, 6, 15),
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('300.000 đ'), findsAtLeast(1));

      final allChip = find.widgetWithText(ChoiceChip, 'Tất cả');
      await tester.dragUntilVisible(
        allChip,
        find.byKey(const Key(StatsScreen.periodBarKey)),
        const Offset(-200, 0),
      );
      await WidgetTestHelper.settle(tester);
      await tester.tap(allChip);
      await WidgetTestHelper.settle(tester);

      expect(find.text('1.200.000 đ'), findsAtLeast(1));
    });

    testWidgets('gom quá 6 người vào mục "Khác" thay vì sinh thêm màu', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 8; i++) DbTestHelper.member('Người $i'),
      ];
      for (final member in many) {
        await MemberDao(database).insert(member);
      }
      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Tiệc đông người',
          total: 800000,
          participants: many,
          payer: many.first,
        ),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.textContaining('Khác (2 người)'), findsOneWidget);
    });
  });

  group('FR-7.13 — Chi phí từng người theo danh mục', () {
    /// Hóa đơn chia đều có gán danh mục.
    Future<void> addBill({
      required int total,
      required List<Member> participants,
      String? categoryId,
    }) async {
      final base = DbTestHelper.equalBill(
        title: 'Hóa đơn',
        total: total,
        participants: participants,
        payer: participants.first,
      );
      await BillDao(database).save(base.copyWith(categoryId: categoryId));
    }

    /// An: 300.000 ăn uống + 200.000 đi lại. Bình: 300.000 ăn uống.
    Future<List<ExpenseCategory>> seedTwoCategories() async {
      final categories = await CategoryDao(database).getAll();
      await addBill(
        total: 300000,
        participants: [an],
        categoryId: categories[0].id,
      );
      await addBill(
        total: 200000,
        participants: [an],
        categoryId: categories[1].id,
      );
      await addBill(
        total: 300000,
        participants: [binh],
        categoryId: categories[0].id,
      );
      return categories;
    }

    /// Mở ô chọn danh mục rồi chọn mục có tên [name].
    Future<void> pickCategory(WidgetTester tester, String name) async {
      await WidgetTestHelper.tapVisible(
        tester,
        find.byKey(const Key('category-member-dropdown')),
      );
      // Mục đang chọn vẫn nằm trong cây, nên menu bật lên có hai bản cùng tên.
      await tester.tap(find.textContaining(name).last);
      await WidgetTestHelper.settle(tester);
    }

    testWidgets('mặc định gộp tất cả danh mục', (tester) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('CHI PHÍ TỪNG NGƯỜI THEO DANH MỤC'), findsOneWidget);
      expect(find.text('Tất cả danh mục'), findsOneWidget);

      // An 500.000 (63%) và Bình 300.000 (38%) trong tổng 800.000. Khớp cả
      // số hóa đơn để không trùng với phần trăm của biểu đồ tròn ở trên.
      expect(find.text('2 hóa đơn · 63%'), findsOneWidget);
      expect(find.text('1 hóa đơn · 38%'), findsOneWidget);
    });

    testWidgets('chọn một danh mục thì chỉ còn tiền của danh mục đó', (
      tester,
    ) async {
      final categories = await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await pickCategory(tester, categories[0].name);

      // Trong "Ăn uống" hai người bằng nhau: 300.000 mỗi người, 50%.
      expect(find.text('1 hóa đơn · 50%'), findsNWidgets(2));
      expect(
        find.text('2 hóa đơn · 63%'),
        findsNothing,
        reason: 'tỷ lệ phải tính lại trong phạm vi danh mục đang chọn',
      );

      await pickCategory(tester, categories[1].name);

      // "Đi lại" chỉ mình An, nên một dòng và chiếm trọn 100%.
      expect(find.text('1 hóa đơn · 100%'), findsOneWidget);
      expect(find.text('200.000 đ'), findsWidgets);
    });

    testWidgets('ẩn một người thì người đó biến mất và tỷ lệ tính lại', (
      tester,
    ) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await WidgetTestHelper.tapVisible(
        tester,
        find.byIcon(Icons.visibility_off_outlined),
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bình'));
      await WidgetTestHelper.settle(tester);
      // Đóng bảng chọn lại để nhìn thấy danh sách phía dưới.
      await tester.tapAt(const Offset(10, 10));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('Đang ẩn 1 người'), findsOneWidget);
      expect(find.text('2 hóa đơn · 100%'), findsOneWidget);
      expect(find.text('2 hóa đơn · 63%'), findsNothing);

      await WidgetTestHelper.tapVisible(tester, find.text('Hiện lại'));

      expect(find.text('2 hóa đơn · 63%'), findsOneWidget);
      expect(find.textContaining('Đang ẩn'), findsNothing);
    });

    testWidgets('thanh tỷ trọng có kích thước thật, không co về 0', (
      tester,
    ) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      final bar = find.byKey(Key('category-member-bar-${an.id}'));
      await WidgetTestHelper.scrollTo(tester, bar);
      final size = tester.getSize(bar);

      // Đếm widget không đủ: đã có lần một thanh dựng ra đủ cả mà không vẽ
      // một pixel nào vì cao 0 (PLAN 13.27). Phải đo **cả hai chiều**.
      expect(size.width, greaterThan(100));
      expect(size.height, 6);
    });

    testWidgets('tổng của mọi danh mục khớp với bảng xếp hạng', (tester) async {
      final categories = await CategoryDao(database).getAll();

      await addBill(
        total: 300000,
        participants: [an],
        categoryId: categories[0].id,
      );
      await addBill(
        total: 200000,
        participants: [an],
        categoryId: categories[1].id,
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // 500.000 xuất hiện ở ô tổng nhóm, bảng xếp hạng, và mục theo danh mục.
      expect(find.text('500.000 đ'), findsWidgets);
    });

    testWidgets('mở màn chia sẻ với đúng danh mục, kỳ và số liệu', (
      tester,
    ) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await WidgetTestHelper.tapVisible(tester, find.byIcon(Icons.ios_share));

      expect(find.text('Chia sẻ báo cáo'), findsOneWidget);
      expect(find.text('Tất cả danh mục'), findsWidgets);
      // Kỳ mặc định là tháng này; màn chia sẻ phải ghi rõ kỳ nào vì người nhận
      // không mở app để tự biết.
      expect(
        find.textContaining('Tháng ${DateTime.now().month}/'),
        findsOneWidget,
      );
      expect(find.text('800.000 đ'), findsOneWidget);
      expect(find.text('Gửi text'), findsOneWidget);
      expect(find.text('Gửi ảnh'), findsOneWidget);
    });

    testWidgets('màn chia sẻ nói rõ đang ẩn bớt người', (tester) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await WidgetTestHelper.tapVisible(
        tester,
        find.byIcon(Icons.visibility_off_outlined),
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bình'));
      await WidgetTestHelper.settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(tester, find.byIcon(Icons.ios_share));

      expect(
        find.textContaining('Đang ẩn 1 người'),
        findsOneWidget,
        reason:
            'gửi đi báo cáo đang lọc mà không nói là làm người đọc hiểu sai',
      );
      // Hai lần: dòng của An và dòng tổng — ẩn Bình rồi thì hai số bằng nhau.
      expect(
        find.text('500.000 đ'),
        findsNWidgets(2),
        reason: 'tổng phải là của những người còn hiện, không phải 800.000',
      );
      expect(find.text('800.000 đ'), findsNothing);
    });

    testWidgets('ẩn hết mọi người thì không cho chia sẻ bảng rỗng', (
      tester,
    ) async {
      await seedTwoCategories();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await WidgetTestHelper.tapVisible(
        tester,
        find.byIcon(Icons.visibility_off_outlined),
      );
      for (final name in ['An', 'Bình']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
        await WidgetTestHelper.settle(tester);
      }
      await tester.tapAt(const Offset(10, 10));
      await WidgetTestHelper.settle(tester);

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.ios_share),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    group('mã QR nhận tiền trong ảnh báo cáo (FR-8.8)', () {
      Future<void> giveSelfBank({String? bin, String? account}) async {
        await MemberDao(database).update(
          self.copyWith(
            bankName: bin == null ? null : 'Vietcombank',
            bankBin: bin,
            bankAccount: account,
            bankHolder: account == null ? null : 'DAO TRONG DUNG',
          ),
        );
      }

      Future<void> openShare(WidgetTester tester) async {
        await seedTwoCategories();
        await WidgetTestHelper.pump(
          tester,
          database: database,
          child: const StatsScreen(),
          size: WidgetTestHelper.tallViewport,
        );
        await WidgetTestHelper.tapVisible(tester, find.byIcon(Icons.ios_share));
      }

      testWidgets('"Tôi" có đủ ngân hàng và tài khoản thì ảnh có mã QR', (
        tester,
      ) async {
        await giveSelfBank(bin: '970436', account: '0123456789');
        await openShare(tester);

        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.textContaining('0123456789'), findsOneWidget);
        expect(
          find.byKey(const Key(ReportShareScreen.missingQrKey)),
          findsNothing,
        );

        // Đo cả hai chiều (PLAN 13.27): khung dựng đủ mà cao 0 thì ảnh gửi đi
        // không có mã nào.
        final size = tester.getSize(
          find.byKey(const Key(PaymentQrBlock.qrKey)),
        );
        expect(size.width, greaterThanOrEqualTo(112));
        expect(size.height, greaterThanOrEqualTo(112));
      });

      testWidgets('QR không điền số tiền: báo cáo có nhiều người, một mã', (
        tester,
      ) async {
        await giveSelfBank(bin: '970436', account: '0123456789');
        await openShare(tester);

        // `QrImageView` không lộ chuỗi dữ liệu ra ngoài, nên kiểm hàm sinh mà
        // khối QR gọi — cùng một hàm, cùng tham số, không có đường sinh khác.
        final payload = PaymentQrBlock.payload(
          self.copyWith(
            bankName: 'Vietcombank',
            bankBin: '970436',
            bankAccount: '0123456789',
          ),
          'Tất cả danh mục',
        )!;
        expect(payload, contains('010211'), reason: '11 = QR tĩnh');
        expect(payload, isNot(contains('010212')));
        // Mỗi người trong báo cáo một số khác nhau; mã điền sẵn một số thì
        // những người còn lại quét ra sai tiền.
        expect(payload, isNot(contains('500000')));
        expect(payload, isNot(contains('800000')));
      });

      testWidgets('chưa nhập thông tin nhận tiền: không QR và có nhắc', (
        tester,
      ) async {
        await openShare(tester);

        expect(find.byType(QrImageView), findsNothing);

        final hint = find.byKey(const Key(ReportShareScreen.missingQrKey));
        expect(hint, findsOneWidget);
        expect(
          find.descendant(of: find.byType(ReportShareCard), matching: hint),
          findsNothing,
          reason: 'lời nhắc dành cho người gửi, không được lọt vào ảnh',
        );
      });

      testWidgets('có tài khoản mà chưa chọn ngân hàng: nhắc đúng lý do', (
        tester,
      ) async {
        await giveSelfBank(account: '0123456789');
        await openShare(tester);

        expect(find.byType(QrImageView), findsNothing);
        expect(find.textContaining('chưa chọn ngân hàng'), findsOneWidget);
        // Vẫn ghi số tài khoản bằng chữ để người ta chuyển tay được.
        expect(find.textContaining('0123456789'), findsOneWidget);
      });
    });

    testWidgets('hóa đơn chưa chọn danh mục vẫn được tính', (tester) async {
      await addBill(total: 300000, participants: [an]);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const StatsScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      await pickCategory(tester, 'Chưa phân loại');

      expect(
        find.text('300.000 đ'),
        findsWidgets,
        reason: 'Bỏ qua hóa đơn chưa phân loại là làm mất tiền khỏi báo cáo',
      );
    });
  });

  group('S07 — Chi tiết thành viên (★ FR-7.1 + FR-7.2)', () {
    testWidgets('hiện tổng chi phí và lịch sử từng hóa đơn', (tester) async {
      await seedBills(count: 3, amount: 300000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
        size: WidgetTestHelper.tallViewport,
      );

      // FR-7.1 — tổng chi phí
      expect(find.text('TỔNG CHI PHÍ'), findsOneWidget);
      // 3 × 100.000. Xuất hiện hai lần: ô "tổng chi phí" và ô "đang nợ",
      // vì An chưa trả đồng nào.
      expect(find.text('300.000 đ'), findsNWidgets(2));
      expect(find.text('3 hóa đơn'), findsAtLeast(1));

      // FR-7.2 — chi phí từng lần theo mỗi hóa đơn
      expect(find.text('LỊCH SỬ TỪNG HÓA ĐƠN'), findsOneWidget);
      expect(find.text('Hóa đơn 1'), findsOneWidget);
      expect(find.text('Hóa đơn 2'), findsOneWidget);
      expect(find.text('Hóa đơn 3'), findsOneWidget);
      expect(find.text('100.000 đ'), findsNWidgets(3));
    });

    testWidgets('hiện số đang nợ và trạng thái từng hóa đơn', (tester) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 900000,
        participants: [self, an, binh],
        payer: self,
      );
      await BillDao(database).save(bill);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('ĐANG NỢ'), findsOneWidget);
      expect(find.text('chưa trả'), findsOneWidget);
    });

    testWidgets('hóa đơn đã trả thì hiện đúng trạng thái', (tester) async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 900000,
        participants: [self, an, binh],
        payer: self,
      );
      await BillDao(database).save(bill);
      await BillDao(database).updateParticipantPayment(
        billId: bill.id,
        memberId: an.id,
        paidAmount: 300000,
        isSettled: true,
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('đã trả'), findsOneWidget);
      expect(find.text('chưa trả'), findsNothing);
    });

    testWidgets('chưa tham gia hóa đơn nào thì báo trạng thái trống', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('Chưa có hóa đơn nào'), findsOneWidget);
    });
  });

  group('S01 — Dashboard (FR-7.8)', () {
    testWidgets('bốn chỉ số và danh sách hóa đơn gần đây', (tester) async {
      await seedBills(count: 2, amount: 900000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const HomeScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      // "Tôi" chịu 300.000 mỗi hóa đơn, hai hóa đơn → 600.000.
      expect(find.text('Bạn đã chi tháng này'), findsOneWidget);
      expect(find.text('600.000 đ'), findsOneWidget);
      expect(find.text('2 hóa đơn'), findsAtLeast(1));

      // "Tôi" ứng trước cả hai hóa đơn nên hai người kia nợ 1.200.000.
      expect(find.text('NGƯỜI KHÁC NỢ BẠN'), findsOneWidget);
      expect(find.text('1.200.000 đ'), findsOneWidget);
      expect(find.text('BẠN ĐANG NỢ'), findsOneWidget);

      expect(find.text('HÓA ĐƠN GẦN ĐÂY'), findsOneWidget);
      expect(find.text('Hóa đơn 1'), findsOneWidget);
      expect(find.textContaining('2 hóa đơn chưa trả xong'), findsOneWidget);
    });

    testWidgets('chưa có hóa đơn thì mời tạo cái đầu tiên', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const HomeScreen(),
        size: WidgetTestHelper.tallViewport,
      );

      expect(find.text('Chưa có hóa đơn nào'), findsOneWidget);
      expect(find.text('Tạo hóa đơn'), findsAtLeast(1));
    });
  });
}
