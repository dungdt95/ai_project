import 'package:chiahoadon/core/utils/avatar_color.dart';
import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/vietqr/vietqr.dart';
import 'package:chiahoadon/features/bills/detail/share_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Mã QR nhận tiền trong ảnh chia sẻ hóa đơn (SPEC FR-8.8).
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;

  setUp(() async {
    database = await WidgetTestHelper.openDb();
  });

  tearDown(() async {
    await database.close();
  });

  /// Người trả trước, có hoặc không có thông tin ngân hàng.
  Member payerWith({String? bin, String? account}) => Member(
    id: 'payer',
    name: 'Dũng',
    nameNorm: VnText.normalize('Dũng'),
    avatarColor: AvatarColor.toStored('Dũng'),
    bankName: bin == null ? null : 'Vietcombank',
    bankBin: bin,
    bankAccount: account,
    bankHolder: account == null ? null : 'DAO TRONG DUNG',
    createdAt: 0,
    updatedAt: 0,
  );

  Future<Bill> seedBill(Member payer, {String title = 'Ăn lẩu'}) async {
    await MemberDao(database).insert(payer);
    final an = DbTestHelper.member('An');
    await MemberDao(database).insert(an);

    return DbTestHelper.equalBill(
      title: title,
      total: 300000,
      participants: [payer, an],
      payer: payer,
    );
  }

  Future<void> openPreview(WidgetTester tester, Bill bill) =>
      WidgetTestHelper.pump(
        tester,
        database: database,
        child: SharePreviewScreen(bill: bill),
        size: WidgetTestHelper.tallViewport,
      );

  group('Sinh chuỗi QR từ hóa đơn', () {
    test('là QR tĩnh: không điền số tiền', () async {
      final payer = payerWith(bin: '970436', account: '0123456789');
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 300000,
        participants: [payer],
        payer: payer,
      );

      final payload = ShareCard.qrPayload(bill, {payer.id: payer})!;

      // Mỗi người trong hóa đơn nợ một số khác nhau mà ảnh chỉ có một mã; điền
      // một số thì những người còn lại quét ra sai tiền.
      expect(payload, contains('010211'), reason: '11 = QR dùng lại nhiều lần');
      expect(payload, isNot(contains('010212')));
      expect(payload, isNot(contains('300000')));
      expect(payload, contains('0123456789'));
      expect(payload, contains('970436'));
    });

    test('nội dung chuyển khoản là tên hóa đơn, bỏ dấu', () async {
      final payer = payerWith(bin: '970436', account: '0123456789');
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu tất niên',
        total: 300000,
        participants: [payer],
        payer: payer,
      );

      final payload = ShareCard.qrPayload(bill, {payer.id: payer})!;

      expect(payload, contains('AN LAU TAT NIEN'));
    });

    test('khớp đúng với QR mà màn "Chuyển khoản" sinh ra', () async {
      final payer = payerWith(bin: '970436', account: '0123456789');
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 300000,
        participants: [payer],
        payer: payer,
      );

      final expected = buildVietQr(
        const VietQrRequest(
          bankBin: '970436',
          accountNumber: '0123456789',
          description: 'Ăn lẩu',
        ),
      );

      expect(ShareCard.qrPayload(bill, {payer.id: payer}), expected);
    });

    test('thiếu ngân hàng thì không dựng QR, không đoán mã BIN', () async {
      final payer = payerWith(account: '0123456789');
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 300000,
        participants: [payer],
        payer: payer,
      );

      expect(ShareCard.qrPayload(bill, {payer.id: payer}), isNull);
    });

    test('không có người trả trước thì không dựng QR', () async {
      final payer = payerWith(bin: '970436', account: '0123456789');
      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu',
        total: 300000,
        participants: [payer],
        payer: payer,
      ).copyWith(payers: const []);

      expect(ShareCard.qrPayload(bill, {payer.id: payer}), isNull);
    });
  });

  group('Ảnh chia sẻ trên màn hình', () {
    testWidgets('đủ ngân hàng và tài khoản thì ảnh có mã QR', (tester) async {
      final bill = await seedBill(
        payerWith(bin: '970436', account: '0123456789'),
      );

      await openPreview(tester, bill);

      expect(find.byType(QrImageView), findsOneWidget);
      // Số tài khoản bằng chữ vẫn phải có: không phải máy nào cũng quét được
      // mã từ một tấm ảnh trong khung chat.
      expect(find.textContaining('0123456789'), findsOneWidget);
      expect(find.textContaining('Quét bằng app ngân hàng'), findsOneWidget);
      expect(
        find.byKey(const Key(SharePreviewScreen.missingQrKey)),
        findsNothing,
      );
    });

    testWidgets('mã QR có kích thước thật và nền trắng để quét được', (
      tester,
    ) async {
      final bill = await seedBill(
        payerWith(bin: '970436', account: '0123456789'),
      );

      await openPreview(tester, bill);

      final frame = find.byKey(const Key(ShareCard.qrKey));
      final size = tester.getSize(frame);

      // Đo cả hai chiều (bài học PLAN 13.27): một khung dựng đủ mà cao 0 thì
      // ảnh gửi đi không có mã nào cả.
      expect(size.width, greaterThanOrEqualTo(112));
      expect(size.height, greaterThanOrEqualTo(112));

      final box = tester.widget<Container>(frame);
      final decoration = box.decoration! as BoxDecoration;
      expect(
        decoration.color,
        Colors.white,
        reason: 'máy quét cần nền trắng, kể cả khi ảnh nằm trên nền chat tối',
      );
    });

    testWidgets('có tài khoản mà chưa chọn ngân hàng: không QR và có nhắc', (
      tester,
    ) async {
      final bill = await seedBill(payerWith(account: '0123456789'));

      await openPreview(tester, bill);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('0123456789'), findsOneWidget);
      expect(
        find.byKey(const Key(SharePreviewScreen.missingQrKey)),
        findsOneWidget,
        reason: 'người dùng tưởng đã nhập đủ — phải nói vì sao thiếu QR',
      );
    });

    testWidgets('lời nhắc thiếu QR không nằm trong ảnh được chụp', (
      tester,
    ) async {
      final bill = await seedBill(payerWith(account: '0123456789'));

      await openPreview(tester, bill);

      // Lời nhắc dành cho người gửi; lọt vào ảnh là cả nhóm đọc thấy.
      final hint = find.byKey(const Key(SharePreviewScreen.missingQrKey));
      expect(
        find.descendant(of: find.byType(ShareCard), matching: hint),
        findsNothing,
      );
      // Vùng được chụp là RepaintBoundary **gần nhất** bọc thẻ; route cũng có
      // RepaintBoundary riêng bọc cả màn hình nên không dùng được để so.
      final captured = find
          .ancestor(
            of: find.byType(ShareCard),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      expect(find.descendant(of: captured, matching: hint), findsNothing);
    });

    testWidgets('chưa có tài khoản nào thì không QR và cũng không nhắc', (
      tester,
    ) async {
      final bill = await seedBill(payerWith());

      await openPreview(tester, bill);

      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.byKey(const Key(SharePreviewScreen.missingQrKey)),
        findsNothing,
      );
    });
  });
}
