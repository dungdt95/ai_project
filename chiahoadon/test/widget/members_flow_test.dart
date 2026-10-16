import 'package:chiahoadon/core/widgets/app_feedback.dart';
import 'package:chiahoadon/core/widgets/member_avatar.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/members/member_form_screen.dart';
import 'package:chiahoadon/features/members/members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;

  setUp(() async {
    database = await WidgetTestHelper.openDb();
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> openMembers(WidgetTester tester) => WidgetTestHelper.pump(
    tester,
    database: database,
    child: const MembersScreen(),
  );

  group('S05 — Danh sách thành viên', () {
    testWidgets('mở app lần đầu đã có thành viên "Tôi"', (tester) async {
      await openMembers(tester);

      expect(find.text('Thành viên'), findsOneWidget);
      expect(find.text('Tôi'), findsAtLeast(1));
      expect(find.byType(MemberAvatar), findsOneWidget);
      // Chưa có ai ngừng hoạt động nên không hiện mục đó.
      expect(find.textContaining('NGỪNG HOẠT ĐỘNG'), findsNothing);
    });

    testWidgets('hiện mục ngừng hoạt động khi có người bị ẩn', (tester) async {
      final dao = MemberDao(database);
      final an = _member('An');
      await dao.insert(an);
      await dao.setActive(an.id, false);

      await openMembers(tester);

      expect(find.text('An'), findsOneWidget);
      expect(find.text('NGỪNG HOẠT ĐỘNG (1)'), findsOneWidget);
    });

    testWidgets('tìm kiếm lọc theo tên, bỏ qua dấu', (tester) async {
      final dao = MemberDao(database);
      await dao.insert(_member('Bình'));
      await dao.insert(_member('Dũng'));

      await openMembers(tester);
      expect(find.text('Bình'), findsOneWidget);
      expect(find.text('Dũng'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await WidgetTestHelper.settle(tester);

      await tester.enterText(find.byType(TextField).first, 'binh');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Bình'), findsOneWidget);
      expect(find.text('Dũng'), findsNothing);
    });

    testWidgets('tìm không ra thì hiện trạng thái trống có nêu từ khóa', (
      tester,
    ) async {
      await openMembers(tester);

      await tester.tap(find.byIcon(Icons.search));
      await WidgetTestHelper.settle(tester);
      await tester.enterText(find.byType(TextField).first, 'xyz');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Không tìm thấy ai'), findsOneWidget);
      // Thông báo nhắc lại từ khóa để người dùng biết mình đã gõ gì.
      expect(
        find.text('Không có thành viên nào khớp với "xyz".'),
        findsOneWidget,
      );
    });
  });

  group('S06 — Luồng thêm thành viên', () {
    testWidgets('thêm thành viên mới rồi thấy ngay trong danh sách', (
      tester,
    ) async {
      await openMembers(tester);

      await tester.tap(find.text('Thêm'));
      await WidgetTestHelper.settle(tester);
      expect(find.text('Thêm thành viên'), findsAtLeast(1));

      await tester.enterText(find.byType(TextFormField).first, 'Nguyễn Văn An');
      await tester.pump();

      await WidgetTestHelper.tapButton(tester, 'Thêm thành viên');

      // Quay về danh sách và người mới đã có mặt.
      expect(find.text('Thành viên'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);

      // Và đã nằm thật trong DB, không chỉ trên UI.
      final saved = await MemberDao(database).getAll();
      expect(saved.map((m) => m.name), contains('Nguyễn Văn An'));
    });

    testWidgets('bỏ trống tên thì không lưu được', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const MemberFormScreen(),
      );

      await WidgetTestHelper.tapButton(tester, 'Thêm thành viên');

      expect(find.text('Tên không được để trống'), findsOneWidget);
      expect(await MemberDao(database).getAll(), hasLength(1));
    });

    testWidgets('cảnh báo khi trùng tên nhưng vẫn cho thêm', (tester) async {
      await MemberDao(database).insert(_member('Anh'));

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const MemberFormScreen(),
      );

      // "anh" không dấu vẫn bị coi là trùng với "Anh".
      await tester.enterText(find.byType(TextFormField).first, 'anh');
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Thêm thành viên');

      expect(find.byType(ConfirmDialog), findsOneWidget);
      expect(find.text('Tên đã tồn tại'), findsOneWidget);

      await tester.tap(find.text('Vẫn thêm'));
      await WidgetTestHelper.settle(tester);

      final saved = await MemberDao(database).getAll();
      expect(saved.where((m) => m.nameNorm == 'anh'), hasLength(2));
    });

    testWidgets('hủy ở hộp thoại trùng tên thì không lưu', (tester) async {
      await MemberDao(database).insert(_member('Anh'));

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const MemberFormScreen(),
      );

      await tester.enterText(find.byType(TextFormField).first, 'Anh');
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Thêm thành viên');

      await tester.tap(find.text('Hủy'));
      await WidgetTestHelper.settle(tester);

      final saved = await MemberDao(database).getAll();
      expect(saved.where((m) => m.nameNorm == 'anh'), hasLength(1));
    });

    testWidgets('sửa tên thành viên đã có', (tester) async {
      final an = _member('An');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberFormScreen(member: an),
      );

      expect(find.text('Sửa thành viên'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'An Nguyễn');
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Lưu thay đổi');

      final saved = await MemberDao(database).getById(an.id);
      expect(saved!.name, 'An Nguyễn');
      // Tên đã bỏ dấu cũng phải được cập nhật, nếu không tìm kiếm sẽ sai.
      expect(saved.nameNorm, 'an nguyen');
    });

    testWidgets('xóa trắng số điện thoại rồi lưu thì nó thật sự mất', (
      tester,
    ) async {
      final an = _member('An').copyWith(phone: '0901234567');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberFormScreen(member: an),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '0901234567'),
        '',
      );
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Lưu thay đổi');

      // Nếu dựng bản ghi mới bằng copyWith với toán tử ?? thì giá trị null bị
      // hiểu là "không đổi", và số cũ ở lại mãi — không có cách nào xóa.
      expect((await MemberDao(database).getById(an.id))!.phone, isNull);
    });
  });

  group('FR-1.6 — Đánh dấu "Tôi"', () {
    testWidgets('chuyển "Tôi" sang người khác, chỉ còn đúng một người', (
      tester,
    ) async {
      final an = _member('An');
      await MemberDao(database).insert(an);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberFormScreen(member: an),
      );

      await tester.tap(find.text('Đặt người này là "Tôi"'));
      await WidgetTestHelper.settle(tester);

      final self = await MemberDao(database).getSelf();
      expect(self!.id, an.id);

      final all = await MemberDao(database).getAll();
      expect(all.where((m) => m.isSelf), hasLength(1));
    });

    testWidgets('bản ghi "Tôi" không có nút chuyển cho chính nó', (
      tester,
    ) async {
      final self = await MemberDao(database).getSelf();

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: MemberFormScreen(member: self),
      );

      expect(find.text('Đặt người này là "Tôi"'), findsNothing);
    });
  });

  group('FR-1.5 — Ẩn thay vì xóa khi đã có dữ liệu liên quan', () {
    testWidgets('thành viên chưa dùng ở đâu thì hộp thoại nói là xóa được', (
      tester,
    ) async {
      final an = _member('An');
      await MemberDao(database).insert(an);

      await openMembers(tester);
      await _slideToActions(tester, find.text('An'));

      await tester.tap(find.text('Ẩn'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('chưa có trong hóa đơn nào'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
    });

    testWidgets('không cho xóa bản ghi "Tôi"', (tester) async {
      await openMembers(tester);
      await _slideToActions(tester, find.text('Tôi').first);

      await tester.tap(find.text('Ẩn'));
      await WidgetTestHelper.settle(tester);

      // Repository chặn và giải thích thay vì mở hộp thoại xác nhận.
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(find.textContaining('Không thể xóa'), findsOneWidget);
    });
  });
}

/// Kéo một dòng sang trái để lộ các hành động của `Slidable`.
Future<void> _slideToActions(WidgetTester tester, Finder row) async {
  await tester.drag(row, const Offset(-250, 0));
  await WidgetTestHelper.settle(tester);
}

/// Thành viên mẫu, dùng lại đúng cách sinh `name_norm` và màu avatar của app.
Member _member(String name) => DbTestHelper.member(name);
