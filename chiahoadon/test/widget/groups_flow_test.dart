import 'package:chiahoadon/core/widgets/member_chip.dart';
import 'package:chiahoadon/data/dao/group_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/groups/group_form_screen.dart';
import 'package:chiahoadon/features/groups/groups_screen.dart';
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

  group('S08 — Danh sách nhóm', () {
    testWidgets('chưa có nhóm thì hiện trạng thái trống có nút tạo', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupsScreen(),
      );

      expect(find.text('Chưa có nhóm nào'), findsOneWidget);
      expect(find.text('Tạo nhóm'), findsAtLeast(1));
    });

    testWidgets('hiện tên nhóm, số người và danh sách thành viên', (
      tester,
    ) async {
      await GroupDao(database).save(
        DbTestHelper.group('Team Dev', members: [an, binh, chi]),
      );

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupsScreen(),
      );

      expect(find.text('Team Dev'), findsOneWidget);
      expect(find.text('3 người'), findsOneWidget);
      expect(find.text('An, Bình, Chi'), findsOneWidget);
    });
  });

  group('S09 — Luồng tạo nhóm', () {
    testWidgets('tạo nhóm bằng bộ chọn thành viên', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupFormScreen(),
      );

      await tester.enterText(find.byType(TextFormField).first, 'Team Dev');
      await tester.pump();

      // Mở bộ chọn thành viên.
      await tester.tap(find.text('Chọn'));
      await WidgetTestHelper.settle(tester);
      expect(find.text('Thành viên của nhóm'), findsOneWidget);

      // Chọn An và Bình, bỏ Chi.
      await tester.tap(find.widgetWithText(MemberChip, 'An'));
      await tester.tap(find.widgetWithText(MemberChip, 'Bình'));
      await WidgetTestHelper.settle(tester);
      expect(find.text('Đã chọn 2'), findsOneWidget);

      await tester.tap(find.text('Xong (2)'));
      await WidgetTestHelper.settle(tester);

      expect(find.text('Thành viên (2)'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Tạo nhóm');

      final saved = await GroupDao(database).getAll();
      expect(saved, hasLength(1));
      expect(saved.first.name, 'Team Dev');
      expect(saved.first.memberIds.toSet(), {an.id, binh.id});
    });

    testWidgets('nút "Tất cả" chọn hết thành viên đang hoạt động', (
      tester,
    ) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupFormScreen(),
      );

      await tester.tap(find.text('Chọn'));
      await WidgetTestHelper.settle(tester);

      await tester.tap(find.text('Tất cả'));
      await WidgetTestHelper.settle(tester);

      // 3 người vừa thêm, cộng bản ghi "Tôi" có sẵn từ dữ liệu khởi tạo.
      expect(find.text('Đã chọn 4'), findsOneWidget);
    });

    testWidgets('bỏ trống tên nhóm thì không lưu được', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupFormScreen(),
      );

      await WidgetTestHelper.tapButton(tester, 'Tạo nhóm');

      expect(find.text('Tên nhóm không được để trống'), findsOneWidget);
      expect(await GroupDao(database).getAll(), isEmpty);
    });

    testWidgets('nhóm không có thành viên thì không lưu được', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupFormScreen(),
      );

      await tester.enterText(find.byType(TextFormField).first, 'Nhóm rỗng');
      await tester.pump();
      await WidgetTestHelper.tapButton(tester, 'Tạo nhóm');

      expect(await GroupDao(database).getAll(), isEmpty);
    });

    testWidgets('sửa nhóm: bỏ một người ra khỏi nhóm', (tester) async {
      final group = DbTestHelper.group('Team Dev', members: [an, binh, chi]);
      await GroupDao(database).save(group);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: GroupFormScreen(group: group),
      );

      expect(find.text('Sửa nhóm'), findsOneWidget);
      expect(find.text('Thành viên (3)'), findsOneWidget);

      // Bỏ người đầu tiên trong danh sách.
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await WidgetTestHelper.settle(tester);
      expect(find.text('Thành viên (2)'), findsOneWidget);

      await WidgetTestHelper.tapButton(tester, 'Lưu thay đổi');

      final saved = await GroupDao(database).getById(group.id);
      expect(saved!.memberIds, hasLength(2));
    });
  });

  group('FR-2.5 — Xóa nhóm không ảnh hưởng hóa đơn', () {
    testWidgets('xóa nhóm chỉ xóa lối tắt, hộp thoại nói rõ điều đó', (
      tester,
    ) async {
      final group = DbTestHelper.group('Team Dev', members: [an, binh]);
      await GroupDao(database).save(group);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const GroupsScreen(),
      );

      await tester.drag(find.text('Team Dev'), const Offset(-250, 0));
      await WidgetTestHelper.settle(tester);

      await tester.tap(find.text('Xóa'));
      await WidgetTestHelper.settle(tester);

      expect(find.textContaining('vẫn giữ nguyên'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await WidgetTestHelper.settle(tester);

      // Soft delete: bản ghi còn trong DB nhưng không còn hiện ra.
      expect(await GroupDao(database).getAll(), isEmpty);
      expect(find.text('Chưa có nhóm nào'), findsOneWidget);
    });
  });
}
