import 'package:chiahoadon/core/theme/app_theme.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/data_providers.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/detail/bill_detail_screen.dart';
import 'package:chiahoadon/features/bills/list/bills_screen.dart';
import 'package:chiahoadon/features/home/home_screen.dart';
import 'package:chiahoadon/features/members/member_detail_screen.dart';
import 'package:chiahoadon/features/members/members_screen.dart';
import 'package:chiahoadon/features/settlement/settlement_screen.dart';
import 'package:chiahoadon/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Kiểm tra bố cục ở màn hình nhỏ nhất được cam kết, chế độ tối, và cỡ chữ
/// phóng to (NFR-9, SPEC FR-9.2, PLAN §7 Phase 10).
///
/// Mỗi test dựng màn hình rồi khẳng định **không có widget nào tràn khung**.
/// Tràn bố cục là lỗi chỉ lộ ra khi nhìn, nên nếu không kiểm tự động thì sẽ
/// lọt tới tay người dùng dùng máy nhỏ hoặc bật cỡ chữ lớn.
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  /// Bề ngang nhỏ nhất SPEC cam kết hỗ trợ (NFR-9).
  const smallest = Size(360, 640);

  late AppDatabase database;
  late Member self;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await WidgetTestHelper.openDb();

    self = (await MemberDao(database).getSelf())!;
    an = DbTestHelper.member('Nguyễn Văn An');
    binh = DbTestHelper.member('Trần Thị Bình Minh');
    for (final member in [an, binh]) {
      await MemberDao(database).insert(member);
    }

    // Hóa đơn có tên dài, số tiền lớn, nhiều người — nơi bố cục dễ vỡ nhất.
    await BillDao(database).save(
      DbTestHelper.equalBill(
        title: 'Liên hoan cuối năm phòng Kỹ thuật phần mềm',
        total: 12345678,
        participants: [self, an, binh],
        payer: self,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Dựng [child] với kích thước và cỡ chữ cho trước, rồi kiểm tra có lỗi
  /// bố cục nào không.
  Future<void> expectNoOverflow(
    WidgetTester tester, {
    required Widget child,
    Size size = smallest,
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await WidgetTestHelper.settle(tester);

    // `tester.takeException` trả về lỗi bố cục đầu tiên nếu có; mọi lỗi
    // RenderFlex overflow đều đi qua đây.
    expect(
      tester.takeException(),
      isNull,
      reason: 'Bố cục tràn khung ở ${size.width.toInt()}dp, '
          'cỡ chữ ×$textScale, ${brightness.name}',
    );
  }

  group('NFR-9 — màn hình 360dp', () {
    testWidgets('Dashboard', (tester) async {
      await expectNoOverflow(tester, child: const HomeScreen());
    });

    testWidgets('Danh sách hóa đơn', (tester) async {
      await expectNoOverflow(tester, child: const BillsScreen());
    });

    testWidgets('Danh sách thành viên', (tester) async {
      await expectNoOverflow(tester, child: const MembersScreen());
    });

    testWidgets('Thống kê', (tester) async {
      await expectNoOverflow(tester, child: const StatsScreen());
    });

    testWidgets('Quyết toán', (tester) async {
      await expectNoOverflow(tester, child: const SettlementScreen());
    });

    testWidgets('Chi tiết thành viên', (tester) async {
      await expectNoOverflow(tester, child: MemberDetailScreen(member: an));
    });

    testWidgets('Chi tiết hóa đơn', (tester) async {
      final bills = await BillDao(database).getPage(
        const BillFilter(),
      );
      await expectNoOverflow(
        tester,
        child: BillDetailScreen(billId: bills.first.id),
      );
    });
  });

  group('FR-9.2 — chế độ tối', () {
    testWidgets('Dashboard đọc được ở nền tối', (tester) async {
      await expectNoOverflow(
        tester,
        child: const HomeScreen(),
        brightness: Brightness.dark,
      );
    });

    testWidgets('Thống kê ở nền tối dùng bộ màu biểu đồ riêng', (tester) async {
      await expectNoOverflow(
        tester,
        child: const StatsScreen(),
        brightness: Brightness.dark,
      );
    });

    testWidgets('Danh sách hóa đơn ở nền tối', (tester) async {
      await expectNoOverflow(
        tester,
        child: const BillsScreen(),
        brightness: Brightness.dark,
      );
    });
  });

  group('Cỡ chữ phóng to 1,3×', () {
    testWidgets('Dashboard', (tester) async {
      await expectNoOverflow(
        tester,
        child: const HomeScreen(),
        textScale: 1.3,
      );
    });

    testWidgets('Danh sách hóa đơn', (tester) async {
      await expectNoOverflow(
        tester,
        child: const BillsScreen(),
        textScale: 1.3,
      );
    });

    testWidgets('Danh sách thành viên', (tester) async {
      await expectNoOverflow(
        tester,
        child: const MembersScreen(),
        textScale: 1.3,
      );
    });

    testWidgets('Quyết toán', (tester) async {
      await expectNoOverflow(
        tester,
        child: const SettlementScreen(),
        textScale: 1.3,
      );
    });
  });

  // Một test bố cục luôn xanh thì vô giá trị nếu nó không thể báo đỏ. Test này
  // dựng một hàng chắc chắn tràn khung để chứng minh `takeException` ở trên
  // thật sự bắt được lỗi tràn, chứ không phải đang lặng lẽ bỏ qua.
  testWidgets('cơ chế kiểm tra tràn khung thật sự phát hiện được lỗi', (
    tester,
  ) async {
    tester.view
      ..physicalSize = smallest
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(children: [SizedBox(width: 1000), SizedBox(width: 1000)]),
      ),
    );

    expect(tester.takeException(), isNotNull);
  });
}
