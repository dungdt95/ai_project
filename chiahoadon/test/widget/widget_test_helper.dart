import 'package:chiahoadon/core/theme/app_theme.dart';
import 'package:chiahoadon/data/data_providers.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tiện ích dựng widget test có cơ sở dữ liệu thật trong bộ nhớ.
///
/// Dùng DB thật thay vì mock repository: `sqflite_common_ffi` chạy SQLite ngay
/// trên máy, nên test đi qua đúng đường mà app chạy thật — kể cả các ràng buộc
/// khóa ngoại và chỉ mục unique — mà vẫn xong trong vài chục mili giây.
class WidgetTestHelper {
  const WidgetTestHelper._();

  static void initFfi() {
    sqfliteFfiInit();

    // `databaseFactoryFfiNoIsolate` thay vì `databaseFactoryFfi`: bản thường
    // chạy truy vấn trên một isolate riêng, cần thời gian thực để xong. Trong
    // widget test thì thời gian là **giả** — `tester.pump(duration)` chỉ tiến
    // đồng hồ ảo — nên Future của isolate không bao giờ hoàn tất và test treo.
    // Bản no-isolate chạy ngay trên isolate test, Future xong trên microtask
    // và `await tester.pump()` xả được chúng.
    databaseFactory = databaseFactoryFfiNoIsolate;
  }

  static Future<AppDatabase> openDb() => AppDatabase.openInMemory();

  /// Dựng [child] trong một `MaterialApp` có theme thật và DB đã ghi đè.
  ///
  /// Khung test mặc định là 800×600 — tỷ lệ ngang, không giống điện thoại nào.
  /// Đặt về 400×800 để bố cục được kiểm tra ở đúng dạng màn hình thật, gần
  /// ngưỡng nhỏ nhất mà NFR-9 cam kết hỗ trợ.
  /// Khung cao bất thường, dùng cho test cần thấy cả màn hình dài cùng lúc
  /// mà không phải cuộn. Chỉ dùng khi điều đang kiểm là nội dung, không phải
  /// bố cục.
  static const Size tallViewport = Size(400, 2400);

  static Future<void> pump(
    WidgetTester tester, {
    required AppDatabase database,
    required Widget child,
    Size size = const Size(400, 800),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: child,
        ),
      ),
    );
    await settle(tester);
  }

  /// Chờ các provider async đọc xong DB và các chuyển cảnh kết thúc.
  ///
  /// Không dùng `pumpAndSettle`: app có `CircularProgressIndicator` trong lúc
  /// tải và trong lúc lưu, mà đó là animation **vô hạn** — `pumpAndSettle` sẽ
  /// chờ mãi rồi báo timeout. Bơm một số frame cố định vừa đủ cho Future của
  /// SQLite hoàn tất và cho hộp thoại chạy hết transition.
  static Future<void> settle(
    WidgetTester tester, {
    int frames = 20,
    Duration step = const Duration(milliseconds: 30),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  }

  /// Cuộn tới nút rồi bấm.
  ///
  /// Nút lưu nằm cuối form dài nên thường ở ngoài vùng hiển thị. `ListView`
  /// dựng con một cách lười, nên widget đó **chưa tồn tại** trong cây —
  /// `ensureVisible` sẽ ném `Bad state: No element`. Phải cuộn cho tới khi nó
  /// được dựng ra trước đã.
  static Future<void> tapButton(WidgetTester tester, String label) =>
      _tapButtonOfType(tester, find.widgetWithText(FilledButton, label));

  /// Chuyển bước chia tiền sang **chia đều**.
  ///
  /// Mặc định của app là chia theo món, nên test nào muốn nhập một tổng tiền
  /// duy nhất phải chọn chia đều trước — đây là đúng thao tác người dùng làm.
  static Future<void> chooseEqualSplit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chia đều'));
    await settle(tester);
  }

  /// Như [tapButton] nhưng cho `OutlinedButton`.
  ///
  /// Cần tách ra vì có chỗ hai nút cùng nhãn: "Thêm món" viền ở danh sách và
  /// "Thêm món" đặc trong sheet nhập món.
  static Future<void> tapOutlinedButton(
    WidgetTester tester,
    String label,
  ) => _tapButtonOfType(tester, find.widgetWithText(OutlinedButton, label));

  static Future<void> _tapButtonOfType(
    WidgetTester tester,
    Finder finder,
  ) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await settle(tester);
    }

    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Cuộn cho tới khi [finder] nằm trong vùng nhìn thấy.
  ///
  /// Cần cả hai bước: `scrollUntilVisible` để widget được **dựng ra** (danh
  /// sách dựng con một cách lười), rồi `ensureVisible` để nó nằm trong
  /// viewport — một widget đã dựng nhưng ở ngoài màn hình vẫn tìm thấy được,
  /// nhưng `tap` sẽ hit-test trượt và **không báo lỗi**, dẫn tới test thất bại
  /// ở chỗ khác với lý do khó hiểu.
  static Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    Key? insideList,
  }) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        // `.first` là bắt buộc: mỗi ô nhập văn bản cũng chứa một `Scrollable`
        // riêng, nên finder không giới hạn sẽ khớp nhiều widget.
        scrollable: insideList == null
            ? find.byType(Scrollable).first
            : find
                  .descendant(
                    of: find.byKey(insideList),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        maxScrolls: 30,
      );
      await settle(tester);
    }

    await tester.ensureVisible(finder);
    await settle(tester);
  }

  /// Cuộn tới rồi chạm vào [finder].
  static Future<void> tapVisible(
    WidgetTester tester,
    Finder finder, {
    Key? insideList,
  }) async {
    await scrollTo(tester, finder, insideList: insideList);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Gõ chữ vào ô nhập đầu tiên khớp [labelOrHint].
  static Future<void> enterTextInField(
    WidgetTester tester,
    String labelOrHint,
    String text,
  ) async {
    await tester.enterText(
      find.ancestor(
        of: find.text(labelOrHint),
        matching: find.byType(TextField),
      ).first,
      text,
    );
    await tester.pump();
  }
}
