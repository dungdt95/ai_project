import 'package:chiahoadon/core/constants/app_constants.dart';
import 'package:chiahoadon/data/dao/settings_dao.dart';
import 'package:chiahoadon/data/data_providers.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/features/settings/settings_screen.dart';
import 'package:chiahoadon/features/shell/app_lock_gate.dart';
import 'package:chiahoadon/services/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_helper.dart';

/// Khóa ứng dụng (PLAN Phase 11).
void main() {
  setUpAll(WidgetTestHelper.initFfi);

  group('Khi nào phải xác thực lại', () {
    final now = DateTime(2026, 10, 3, 12);

    test('khóa tắt thì không bao giờ hỏi', () {
      expect(
        shouldRelock(lockEnabled: false, leftAt: null, now: now),
        isFalse,
      );
      expect(
        shouldRelock(
          lockEnabled: false,
          leftAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('mới khởi động app thì phải xác thực', () {
      expect(shouldRelock(lockEnabled: true, leftAt: null, now: now), isTrue);
    });

    test('rời app một lát rồi quay lại thì không hỏi', () {
      // Luồng dùng thật: mở QR rồi nhảy sang app ngân hàng rồi quay lại. Hỏi
      // vân tay mỗi lần như vậy thì người dùng sẽ tắt hẳn tính năng này.
      expect(
        shouldRelock(
          lockEnabled: true,
          leftAt: now.subtract(const Duration(seconds: 5)),
          now: now,
        ),
        isFalse,
      );
    });

    test('rời app lâu hơn thời gian ân hạn thì hỏi lại', () {
      expect(
        shouldRelock(
          lockEnabled: true,
          leftAt: now.subtract(AppConstants.appLockGrace),
          now: now,
        ),
        isTrue,
      );
      expect(
        shouldRelock(
          lockEnabled: true,
          leftAt: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        isTrue,
      );
    });

    test('đúng mốc ân hạn là đã phải hỏi, không phải sau đó', () {
      final boundary = now.subtract(AppConstants.appLockGrace);

      expect(
        shouldRelock(lockEnabled: true, leftAt: boundary, now: now),
        isTrue,
      );
      expect(
        shouldRelock(
          lockEnabled: true,
          leftAt: boundary.add(const Duration(milliseconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('Màn che', () {
    late AppDatabase database;

    setUp(() async {
      database = await WidgetTestHelper.openDb();
    });

    tearDown(() async {
      await database.close();
    });

    /// Dựng cổng khóa với một bộ xác thực giả.
    Future<void> pumpGate(
      WidgetTester tester, {
      required bool lockEnabled,
      required Authenticator authenticator,
    }) async {
      if (lockEnabled) {
        await SettingsDao(database).setAppLockEnabled(true);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            authenticatorProvider.overrideWithValue(authenticator),
          ],
          child: const MaterialApp(
            home: AppLockGate(child: Scaffold(body: Text('Nội dung app'))),
          ),
        ),
      );
      await WidgetTestHelper.settle(tester);
    }

    testWidgets('khóa tắt thì vào thẳng app', (tester) async {
      await pumpGate(
        tester,
        lockEnabled: false,
        authenticator: _FakeAuthenticator(passes: false),
      );

      expect(find.text('Nội dung app'), findsOneWidget);
      expect(find.text('Ứng dụng đang khóa.'), findsNothing);
    });

    testWidgets('khóa bật thì tự hỏi xác thực ngay, không bắt bấm thêm', (
      tester,
    ) async {
      final authenticator = _FakeAuthenticator(passes: true);
      await pumpGate(
        tester,
        lockEnabled: true,
        authenticator: authenticator,
      );

      expect(
        authenticator.calls,
        1,
        reason: 'App khóa màn hình nào cũng hỏi ngay khi mở',
      );
      expect(find.text('Nội dung app'), findsOneWidget);
    });

    testWidgets('nội dung không lọt ra trước khi xác thực xong', (
      tester,
    ) async {
      await pumpGate(
        tester,
        lockEnabled: true,
        authenticator: _FakeAuthenticator(passes: false),
      );

      expect(
        find.text('Nội dung app'),
        findsNothing,
        reason: 'Nội dung lọt ra dù chỉ một frame là đã hỏng mục đích của khóa',
      );
      expect(find.text('Ứng dụng đang khóa.'), findsOneWidget);
    });

    testWidgets('bật khóa từ Cài đặt thì không bị hỏi xác thực lần nữa', (
      tester,
    ) async {
      final authenticator = _FakeAuthenticator(passes: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            authenticatorProvider.overrideWithValue(authenticator),
          ],
          child: const MaterialApp(
            home: AppLockGate(child: SettingsScreen()),
          ),
        ),
      );
      await WidgetTestHelper.settle(tester);

      await WidgetTestHelper.scrollTo(tester, find.text('Khóa ứng dụng'));
      await tester.tap(find.byType(SwitchListTile));
      await WidgetTestHelper.settle(tester);

      // Một lần xác thực để bật khóa, và chỉ một lần: xác thực xong lại bị
      // chính màn khóa chặn lại là vô lý.
      expect(authenticator.calls, 1);
      expect(find.text('Ứng dụng đang khóa.'), findsNothing);
      expect(find.text('Khóa ứng dụng'), findsOneWidget);
    });

    testWidgets('máy gỡ mất mã khóa thì mở app ra, không nhốt người dùng', (
      tester,
    ) async {
      // Bật khóa rồi vào cài đặt máy gỡ vân tay và mã khóa màn hình: giờ không
      // còn cách nào xác thực. Dữ liệu chỉ nằm trên máy này nên khóa chặt là
      // mất luôn sổ nợ.
      final authenticator = _FakeAuthenticator(passes: false, available: false);
      await pumpGate(
        tester,
        lockEnabled: true,
        authenticator: authenticator,
      );

      expect(find.text('Nội dung app'), findsOneWidget);
      expect(
        authenticator.calls,
        0,
        reason: 'Không gọi xác thực khi biết chắc là không xác thực được',
      );
      expect(
        await SettingsDao(database).appLockEnabled(),
        isFalse,
        reason: 'Tự tắt khóa, nếu không thì lần mở sau lại kẹt y như vậy',
      );
    });

    testWidgets('xác thực hỏng thì vẫn khóa, và cho thử lại', (tester) async {
      final authenticator = _FakeAuthenticator(passes: false);
      await pumpGate(
        tester,
        lockEnabled: true,
        authenticator: authenticator,
      );

      // Lần hỏi đầu là tự động và đã trượt.
      expect(authenticator.calls, 1);
      expect(find.text('Nội dung app'), findsNothing);
      expect(find.text('Ứng dụng đang khóa.'), findsOneWidget);

      // Không tự hỏi lại: hỏi lại tự động sau khi người dùng bấm hủy sẽ thành
      // vòng lặp hộp thoại không thoát ra được.
      await WidgetTestHelper.settle(tester);
      expect(authenticator.calls, 1);

      // Nhưng nút vẫn cho thử lại, để màn khóa không thành ngõ cụt.
      await WidgetTestHelper.tapButton(tester, 'Mở khóa');
      expect(authenticator.calls, 2);
    });
  });
}

/// Bộ xác thực giả: thao tác sinh trắc học không chạy được trong widget test.
class _FakeAuthenticator implements Authenticator {
  _FakeAuthenticator({required this.passes, this.available = true});

  final bool passes;
  final bool available;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    calls++;
    return passes;
  }
}
