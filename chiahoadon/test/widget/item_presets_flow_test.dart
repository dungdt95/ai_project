import 'package:chiahoadon/core/utils/vn_text.dart';
import 'package:chiahoadon/data/dao/item_preset_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/item_preset.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/features/bills/form/item_editor.dart';
import 'package:chiahoadon/features/items/item_preset_picker.dart';
import 'package:chiahoadon/features/items/item_presets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';
import 'widget_test_helper.dart';

/// Danh sách món đặt sẵn tên và giá, và cách nó nối vào màn nhập hóa đơn.
///
/// Tên món dùng trong test cố tình khác chuỗi gợi ý sẵn của ô "Tên món"
/// ("Lẩu thái"), nếu không thì finder khớp luôn cả chữ mờ trong ô đang trống.
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  late AppDatabase database;
  late ItemPresetDao dao;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await WidgetTestHelper.openDb();
    dao = ItemPresetDao(database);

    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [an, binh]) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Ghi thẳng một món vào DB, bỏ qua giao diện.
  Future<void> seedPreset(String name, int price) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.save(
      ItemPreset(
        id: DbTestHelper.uuid.v4(),
        name: name,
        nameNorm: VnText.normalize(name),
        unitPrice: price,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Mở sheet nhập món từ một màn hình tối giản.
  Future<void> openItemEditor(WidgetTester tester) async {
    await WidgetTestHelper.pump(
      tester,
      database: database,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  ItemEditorSheet.show(context, participants: [an, binh]),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await WidgetTestHelper.tapButton(tester, 'Mở');
  }

  /// Chỉ tìm bên trong bộ chọn món.
  ///
  /// Sheet nhập món nằm ngay dưới và cũng có nút "Thêm món", nên finder không
  /// giới hạn sẽ khớp cả hai.
  Finder inPicker(Finder matching) =>
      find.descendant(of: find.byType(ItemPresetPicker), matching: matching);

  group('Màn quản lý món', () {
    testWidgets('chưa có món nào thì nói rõ dùng để làm gì', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const ItemPresetsScreen(),
      );

      expect(find.text('Chưa có món nào'), findsOneWidget);
    });

    testWidgets('thêm món rồi thấy ngay trong danh sách', (tester) async {
      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const ItemPresetsScreen(),
      );

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm món'));
      await WidgetTestHelper.settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Lẩu riêu cua');
      await WidgetTestHelper.enterTextInField(tester, 'Giá một người', '500000');
      await WidgetTestHelper.tapButton(tester, 'Lưu món');

      expect(find.text('Lẩu riêu cua'), findsOneWidget);
      expect(find.text('500.000 đ'), findsOneWidget);
      expect(await dao.count(), 1);
    });

    testWidgets('món chưa đặt giá thì nói rõ, không hiện 0 đ', (tester) async {
      await seedPreset('Rau thêm', 0);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const ItemPresetsScreen(),
      );

      expect(find.text('Chưa đặt giá'), findsOneWidget);
      expect(
        find.text('0 đ'),
        findsNothing,
        reason: 'Chưa đặt giá khác với giá bằng không',
      );
    });

    testWidgets('xóa món, và nói rõ hóa đơn cũ không bị ảnh hưởng', (
      tester,
    ) async {
      await seedPreset('Lẩu riêu cua', 500000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const ItemPresetsScreen(),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await WidgetTestHelper.settle(tester);

      expect(
        find.textContaining('hóa đơn đã lưu giữ nguyên'),
        findsOneWidget,
        reason: 'Không nói rõ thì người dùng sợ xóa mất số của hóa đơn cũ',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await WidgetTestHelper.settle(tester);

      expect(await dao.count(), 0);
    });

    testWidgets('thêm món trùng tên thì báo lỗi, không ghi đè', (tester) async {
      await seedPreset('Lẩu riêu cua', 500000);

      await WidgetTestHelper.pump(
        tester,
        database: database,
        child: const ItemPresetsScreen(),
      );

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm món'));
      await WidgetTestHelper.settle(tester);

      // Khác dấu và khác hoa thường, nhưng vẫn là cùng một món.
      await tester.enterText(find.byType(TextField).first, 'LAU RIEU CUA');
      await WidgetTestHelper.enterTextInField(tester, 'Giá một người', '9000');
      await WidgetTestHelper.tapButton(tester, 'Lưu món');

      expect(find.textContaining('Đã có món tên'), findsOneWidget);
      expect(await dao.count(), 1);
      expect(
        (await dao.getAll()).first.unitPrice,
        500000,
        reason: 'Giá cũ không được ghi đè',
      );
    });
  });

  group('Chọn món có sẵn khi nhập hóa đơn', () {
    testWidgets('chọn một món thì điền sẵn cả tên lẫn giá', (tester) async {
      await seedPreset('Lẩu riêu cua', 500000);
      await openItemEditor(tester);

      await WidgetTestHelper.tapButton(tester, 'Chọn món có sẵn');
      expect(find.text('Chọn món'), findsOneWidget);

      await tester.tap(inPicker(find.text('Lẩu riêu cua')));
      await WidgetTestHelper.settle(tester);

      expect(find.widgetWithText(TextField, 'Lẩu riêu cua'), findsOneWidget);
      // Giá một người 500.000, hai người ăn → 1.000.000.
      expect(find.textContaining('× 2 phần'), findsOneWidget);
      expect(find.textContaining('1.000.000'), findsAtLeast(1));
    });

    testWidgets('tìm món bỏ dấu', (tester) async {
      await seedPreset('Lẩu riêu cua', 500000);
      await seedPreset('Bia Sài Gòn', 20000);
      await openItemEditor(tester);

      await WidgetTestHelper.tapButton(tester, 'Chọn món có sẵn');
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm món'),
        'bia sai gon',
      );
      await WidgetTestHelper.settle(tester);

      expect(inPicker(find.text('Bia Sài Gòn')), findsOneWidget);
      expect(inPicker(find.text('Lẩu riêu cua')), findsNothing);
    });

    testWidgets('chưa có món nào thì mời thêm ngay tại chỗ', (tester) async {
      await openItemEditor(tester);

      await WidgetTestHelper.tapOutlinedButton(tester, 'Chọn món có sẵn');

      expect(find.text('Chưa có món nào'), findsOneWidget);
      expect(
        inPicker(find.widgetWithText(FilledButton, 'Thêm món')),
        findsOneWidget,
        reason: 'Đang nhập dở hóa đơn, không bắt thoát ra màn quản lý',
      );
    });

    testWidgets('gõ tay một món thì được mời lưu lại để dùng sau', (
      tester,
    ) async {
      await openItemEditor(tester);

      // Chưa nhập gì thì chưa mời lưu.
      expect(find.text('Lưu vào món có sẵn'), findsNothing);

      await WidgetTestHelper.enterTextInField(tester, 'Tên món *', 'Gỏi cuốn');
      await WidgetTestHelper.enterTextInField(tester, 'Giá một người', '45000');
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.tapVisible(tester, find.text('Lưu vào món có sẵn'));

      final saved = await dao.getAll();
      expect(saved, hasLength(1));
      expect(saved.first.name, 'Gỏi cuốn');
      expect(
        saved.first.unitPrice,
        45000,
        reason: 'Lưu đơn giá, không lưu thành tiền của lần ăn này',
      );
    });

    testWidgets('mở sheet thêm món thì bàn phím không tự bật', (tester) async {
      await seedPreset('Gỏi cuốn', 45000);
      await openItemEditor(tester);

      // Ô tên không được giữ focus: focus ở đó là bàn phím chồm lên che mất
      // danh sách người dùng món, đúng lúc người ta định chọn món có sẵn.
      final nameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Tên món *'),
      );
      expect(nameField.autofocus, isFalse);
      // Nút `FilledButton` hay chính route vẫn có thể giữ focus; điều cần
      // kiểm là **ô nhập** nào cũng không.
      for (final editable in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(
          editable.focusNode.hasFocus,
          isFalse,
          reason: 'không ô nhập nào được giữ focus khi vừa mở sheet',
        );
      }
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('có món sẵn thì nút chọn món là nút chính, không phải viền', (
      tester,
    ) async {
      await seedPreset('Gỏi cuốn', 45000);
      await openItemEditor(tester);

      // Nút đặc (tonal) nghĩa là đường ưu tiên; nút viền là đường phụ.
      expect(
        find.widgetWithText(FilledButton, 'Chọn món có sẵn'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Chọn món có sẵn'),
        findsNothing,
      );
    });

    testWidgets('chưa có món sẵn nào thì nút giữ dạng phụ', (tester) async {
      await openItemEditor(tester);

      expect(
        find.widgetWithText(OutlinedButton, 'Chọn món có sẵn'),
        findsOneWidget,
        reason: 'chưa có gì để chọn thì đừng làm nút này lấn ô nhập tay',
      );
    });

    testWidgets('món đã có trong danh sách thì không mời lưu nữa', (
      tester,
    ) async {
      await seedPreset('Gỏi cuốn', 45000);
      await openItemEditor(tester);

      await WidgetTestHelper.enterTextInField(tester, 'Tên món *', 'Gỏi cuốn');
      await WidgetTestHelper.enterTextInField(tester, 'Giá một người', '45000');
      await WidgetTestHelper.settle(tester);

      expect(find.text('Lưu vào món có sẵn'), findsNothing);
    });
  });
}
