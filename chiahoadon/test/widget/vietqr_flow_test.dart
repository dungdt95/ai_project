import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/members/member_detail_screen.dart';
import 'package:chiahoadon/features/settlement/transfer_qr_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Luồng QR chuyển khoản (SPEC FR-6.7).
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;

  setUp(() async {
    database = await WidgetTestHelper.openDb();
  });

  tearDown(() async {
    await database.close();
  });

  /// Thành viên đã điền đủ thông tin nhận tiền.
  Member withBank(String name) => DbTestHelper.member(name).copyWith(
    bankName: 'Vietcombank',
    bankBin: '970436',
    bankAccount: '1234567890',
    bankHolder: 'NGUYEN VAN AN',
  );

  group('S07 — Chi tiết thành viên', () {
    testWidgets('có thông tin nhận tiền thì hiện nút QR', (tester) async {
      final an = withBank('An');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
      );

      expect(find.text('QR nhận tiền'), findsOneWidget);
    });

    testWidgets('chưa có số tài khoản thì không hiện nút QR', (tester) async {
      final binh = DbTestHelper.member('Bình');
      await MemberDao(database).insert(binh);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: binh),
      );

      expect(
        find.text('QR nhận tiền'),
        findsNothing,
        reason: 'Nút mở ra một mã QR không sinh được thì chỉ gây hụt hẫng',
      );
    });

    testWidgets('chạm nút QR thì mã hiện ra kèm số tài khoản', (tester) async {
      final an = withBank('An');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
      );

      await WidgetTestHelper.tapVisible(tester, find.text('QR nhận tiền'));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Chuyển cho An'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('NGUYEN VAN AN'), findsOneWidget);
      expect(
        find.text('Người quét tự nhập số tiền'),
        findsOneWidget,
        reason: 'Mở từ hồ sơ thì chưa biết số tiền',
      );
    });
  });

  group('Chi tiết thành viên bám theo dữ liệu mới nhất', () {
    testWidgets('sửa thông tin xong thì màn chi tiết cập nhật ngay', (
      tester,
    ) async {
      final an = DbTestHelper.member('An');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberDetailScreen(member: an),
      );

      expect(find.text('0909123456'), findsNothing);

      // Đi đúng đường người dùng đi: từ màn chi tiết bấm sửa, nhập, lưu, rồi
      // form tự đóng và trả về màn chi tiết.
      await WidgetTestHelper.tapVisible(
        tester,
        find.byIcon(Icons.edit_outlined),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại'),
        '0909123456',
      );
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Lưu thay đổi');

      // Màn chi tiết giữ bản chụp cũ của thành viên thì người dùng phải thoát
      // ra rồi vào lại mới thấy thay đổi của chính mình.
      expect(find.text('0909123456'), findsOneWidget);
    });
  });

  group('Sheet QR', () {
    testWidgets('có số tiền thì hiện số tiền thay vì lời nhắc tự nhập', (
      tester,
    ) async {
      final an = withBank('An');

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => TransferQrSheet.show(
                  context,
                  payee: an,
                  amount: 250000,
                  note: 'Chia hoa don',
                ),
                child: const Text('Mở QR'),
              ),
            ),
          ),
        ),
      );

      await WidgetTestHelper.tapButton(tester, 'Mở QR');

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('250.000 đ'), findsOneWidget);
      expect(find.text('Người quét tự nhập số tiền'), findsNothing);
    });

    testWidgets('thiếu thông tin ngân hàng thì nói rõ thiếu gì', (
      tester,
    ) async {
      final binh = DbTestHelper.member('Bình');

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => TransferQrSheet.show(context, payee: binh),
                child: const Text('Mở QR'),
              ),
            ),
          ),
        ),
      );

      await WidgetTestHelper.tapButton(tester, 'Mở QR');

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Chưa chọn ngân hàng nhận tiền.'), findsOneWidget);
      expect(
        find.text('Mở hồ sơ thành viên để bổ sung thông tin nhận tiền.'),
        findsOneWidget,
        reason: 'Báo thiếu mà không nói sửa ở đâu thì người dùng mắc kẹt',
      );
    });
  });
}
