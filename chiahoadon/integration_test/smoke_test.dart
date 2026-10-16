import 'dart:io';

import 'package:chiahoadon/app.dart';
import 'package:chiahoadon/core/constants/app_constants.dart';
import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/data_providers.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/bill_item.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/models/surcharge.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/features/bills/form/bill_form_state.dart';
import 'package:chiahoadon/features/settings/settings_provider.dart';
import 'package:chiahoadon/features/settlement/transfer_qr_sheet.dart';
import 'package:chiahoadon/services/csv_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite/sqflite.dart';

/// Smoke test chạy trên thiết bị Android thật (PLAN §8.3).
///
/// Khác hẳn widget test: ở đây là SQLite thật ghi xuống ổ của máy, đường dẫn
/// thật do hệ điều hành cấp, phông chữ thật được nạp, và mã đã biên dịch AOT
/// chứ không phải chạy trên máy ảo Dart của máy tính. Những thứ đó chỉ hỏng
/// trên thiết bị, widget test không có cách nào bắt được.
///
///     flutter test integration_test/smoke_test.dart -d <thiết bị>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Xóa DB cũ để mỗi lần chạy đều bắt đầu từ máy sạch.
  ///
  /// Cần cho bước 1 của §8.3 — "mở app lần đầu" — và để các khẳng định về số
  /// lượng không phụ thuộc vào lần chạy trước còn sót dữ liệu.
  Future<AppDatabase> freshDatabase() async {
    final path = p.join(await getDatabasesPath(), AppConstants.dbFileName);
    if (File(path).existsSync()) {
      await deleteDatabase(path);
    }
    return AppDatabase.open();
  }

  /// Bơm một số frame cố định thay vì `pumpAndSettle`.
  ///
  /// Lý do giống widget test: vòng xoay chờ là animation vô hạn nên
  /// `pumpAndSettle` sẽ chờ tới lúc hết giờ rồi báo lỗi.
  Future<void> settle(WidgetTester tester, {int frames = 25}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Chuyển lần lượt qua các tab và khẳng định không tab nào dựng lỗi.
  Future<void> visitAllTabs(WidgetTester tester, {required String mode}) async {
    for (final tab in ['Hóa đơn', 'Thống kê', 'Khác', 'Trang chủ']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Tab "$tab" dựng lỗi trên máy thật ($mode)',
      );
    }
  }

  group('§8.3 — smoke test trên thiết bị', () {
    testWidgets('1. mở lần đầu: có "Tôi", 7 danh mục, 4 tab đi lại được', (
      tester,
    ) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      final self =
          (await container.read(memberRepositoryProvider).getSelf()).valueOrNull;
      expect(self, isNotNull, reason: 'App phải tự tạo thành viên "Tôi"');
      expect(self!.isSelf, isTrue);

      final categories = await container.read(categoryDaoProvider).getAll();
      expect(categories, hasLength(7), reason: '7 danh mục mặc định');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ChiaHoaDonApp(),
        ),
      );
      await settle(tester);

      await visitAllTabs(tester, mode: 'nền sáng');
    });

    testWidgets('2–7. vòng đời một hóa đơn, tính trên SQLite của máy', (
      tester,
    ) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      // Bước 2: bốn thành viên và một nhóm chứa cả bốn.
      final members = container.read(memberRepositoryProvider);
      final self = (await members.getSelf()).valueOrNull!;
      final an = (await members.create(name: 'An')).valueOrNull!;
      final binh = (await members.create(name: 'Bình')).valueOrNull!;
      final chi = (await members.create(name: 'Chi')).valueOrNull!;

      final group = (await container.read(groupRepositoryProvider).create(
        name: 'Phòng Kỹ thuật',
        memberIds: [self.id, an.id, binh.id, chi.id],
      )).valueOrNull;
      expect(group, isNotNull);
      expect(group!.memberIds, hasLength(4));

      final names = {an.id: 'An', binh.id: 'Bình', chi.id: 'Chi'};
      final bills = container.read(billRepositoryProvider);

      // Bước 3: chia đều 1.000.000 cho ba người, không làm tròn.
      final equal = (await bills.save(
        _bill(
          BillFormState.create(date: DateTime.now(), self: self).copyWith(
            title: 'Ăn trưa',
            participantIds: [an.id, binh.id, chi.id],
            payerId: an.id,
            manualTotal: 1000000,
            roundingUnit: 1,
            roundingMode: RoundingMode.none,
          ),
          names,
        ),
      )).valueOrNull;
      expect(equal, isNotNull, reason: 'Lưu hóa đơn chia đều phải thành công');
      expect(
        equal!.participants.fold<int>(0, (sum, each) => sum + each.shareAmount),
        1000000,
        reason: 'Σ phần chia phải bằng đúng tổng hóa đơn',
      );

      // Bước 4: chia theo món đúng ví dụ FR-4.2, cộng VAT 8% và phí dịch vụ
      // 5%, làm tròn lên bội số 1.000đ.
      final itemized = (await bills.save(
        _bill(
          BillFormState.create(date: DateTime.now(), self: self).copyWith(
            title: 'Lẩu nướng',
            participantIds: [an.id, binh.id, chi.id],
            payerId: an.id,
            splitType: SplitType.itemized,
            inputMode: InputMode.items,
            items: [
              _item('i1', 'Phở bò', 60000, 0, [an.id, binh.id]),
              _item('i2', 'Bún chả', 55000, 1, [chi.id]),
              _item('i3', 'Trà đá', 5000, 2, [an.id, binh.id, chi.id]),
              _item('i4', 'Cà phê', 25000, 3, [an.id]),
            ],
            tax: const Surcharge.percent(800),
            service: const Surcharge.percent(500),
            roundingUnit: 1000,
            roundingMode: RoundingMode.up,
          ),
          names,
        ),
      )).valueOrNull;
      expect(itemized, isNotNull);

      // Đọc lại từ DB chứ không dùng đối tượng vừa ghi: điều cần kiểm là dữ
      // liệu **trên ổ đĩa** đúng, không phải đối tượng trong bộ nhớ đúng.
      final reread = (await bills.getById(itemized!.id)).valueOrNull!;
      int shareOf(Member member) => reread.participants
          .firstWhere((each) => each.memberId == member.id)
          .shareAmount;

      // Giá món là giá một người: phở 60.000 × 2 người, v.v.
      expect(reread.totalAmount, 243000);
      expect(shareOf(an), 102000);
      expect(shareOf(binh), 73000);
      expect(shareOf(chi), 68000);
      expect(
        shareOf(an) + shareOf(binh) + shareOf(chi),
        reread.totalAmount,
        reason: 'Bất biến Σ phần chia = tổng hóa đơn (SPEC NFR-6)',
      );

      // Bước 5: một người trả đủ, một người trả một phần.
      await bills.setParticipantPaid(
        billId: reread.id,
        memberId: binh.id,
        paidAmount: shareOf(binh),
        shareAmount: shareOf(binh),
      );
      await bills.setParticipantPaid(
        billId: reread.id,
        memberId: chi.id,
        paidAmount: 50000,
        shareAmount: shareOf(chi),
      );

      expect(
        (await bills.getById(reread.id)).valueOrNull!.status,
        BillStatus.partial,
        reason: 'Còn người chưa trả đủ thì hóa đơn ở trạng thái "Một phần"',
      );

      // Bước 6: quyết toán cân bằng.
      final settlement = container.read(settlementRepositoryProvider);
      expect(
        (await settlement.balanceSum()).valueOrNull,
        0,
        reason: 'Tổng các số dư phải triệt tiêu nhau',
      );

      // Bước 7: thống kê của một thành viên khớp với hóa đơn đã nhập.
      final stats = container.read(statsRepositoryProvider);
      final summary = (await stats.memberSummary(
        an.id,
        range: DateRange.allTime(),
      )).valueOrNull!;
      expect(summary.billCount, 2, reason: 'An tham gia cả hai hóa đơn');

      final timeline = (await stats.memberTimeline(
        an.id,
        range: DateRange.allTime(),
      )).valueOrNull!;
      expect(
        timeline.fold<int>(0, (sum, entry) => sum + entry.shareAmount),
        summary.totalSpent,
        reason: 'Tổng chi phải bằng tổng các lần chi — FR-7.2',
      );
    });

    testWidgets('9. sao lưu → xóa sạch → phục hồi, dữ liệu về nguyên vẹn', (
      tester,
    ) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      final members = container.read(memberRepositoryProvider);
      final self = (await members.getSelf()).valueOrNull!;
      final an = (await members.create(name: 'An')).valueOrNull!;

      final bills = container.read(billRepositoryProvider);
      final bill = (await bills.save(
        _bill(
          BillFormState.create(date: DateTime.now(), self: self).copyWith(
            title: 'Cà phê',
            participantIds: [self.id, an.id],
            payerId: self.id,
            manualTotal: 100000,
          ),
          {self.id: self.name, an.id: 'An'},
        ),
      )).valueOrNull!;

      final backup = container.read(backupServiceProvider);
      final json = (await backup.export()).valueOrNull;
      expect(json, isNotNull, reason: 'Xuất sao lưu phải thành công');

      await backup.resetAll();
      expect(
        (await bills.count(const BillFilter())).valueOrNull,
        0,
        reason: 'Sau khi xóa sạch thì không còn hóa đơn nào',
      );

      final info = (await backup.restore(json!)).valueOrNull;
      expect(info, isNotNull, reason: 'Phục hồi phải thành công');

      final restored = (await bills.getById(bill.id)).valueOrNull;
      expect(restored, isNotNull, reason: 'Hóa đơn phải trở lại sau phục hồi');
      expect(restored!.title, 'Cà phê');
      expect(restored.totalAmount, bill.totalAmount);
      expect(
        restored.participants.fold<int>(0, (sum, each) => sum + each.shareAmount),
        restored.totalAmount,
      );
    });

    testWidgets('10. chế độ tối: mọi tab vẫn dựng được', (tester) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      // Ghi thẳng vào cài đặt rồi mới dựng app, để app nạp chế độ tối ngay từ
      // khung hình đầu thay vì đổi theme giữa chừng.
      await container.read(settingsDaoProvider).setThemeMode('dark');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ChiaHoaDonApp(),
        ),
      );
      await settle(tester);

      await visitAllTabs(tester, mode: 'nền tối');
    });

    testWidgets('FR-6.7 — QR chuyển khoản dựng được trên thiết bị', (
      tester,
    ) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      final an = (await container.read(memberRepositoryProvider).create(
        name: 'An',
        bankName: 'Vietcombank',
        bankBin: '970436',
        bankAccount: '1234567890',
        bankHolder: 'NGUYEN VAN AN',
      )).valueOrNull!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TransferQrSheet(payee: an, amount: 250000, note: 'Lau'),
          ),
        ),
      );
      await settle(tester);

      // Vẽ ma trận QR là việc của thư viện bên ngoài: trên máy tính nó chạy
      // qua Skia của Flutter test, trên thiết bị là Impeller thật.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FR-8.3 — tệp CSV ghi xuống ổ của máy vẫn đúng mã hóa', (
      tester,
    ) async {
      final database = await freshDatabase();
      addTearDown(database.close);

      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(database)],
      );

      final members = container.read(memberRepositoryProvider);
      final self = (await members.getSelf()).valueOrNull!;
      final an = (await members.create(name: 'An')).valueOrNull!;

      final bills = container.read(billRepositoryProvider);
      await bills.save(
        _bill(
          BillFormState.create(date: DateTime.now(), self: self).copyWith(
            title: 'Ăn lẩu tất niên; có cả bia',
            participantIds: [self.id, an.id],
            payerId: self.id,
            manualTotal: 500000,
          ),
          {self.id: self.name, an.id: 'An'},
        ),
      );

      final saved =
          (await bills.getPage(const BillFilter(includeDrafts: false)))
              .valueOrNull!;
      final csv = CsvExport.build(saved, members: {self.id: self, an.id: an});

      // Đi qua đúng đường thật: ghi ra tệp rồi đọc lại. Chữ có dấu và dấu bọc
      // ô chỉ hỏng khi đi qua hệ tệp, không hỏng lúc còn trong bộ nhớ.
      final file = File(
        p.join((await getTemporaryDirectory()).path, CsvExport.fileName()),
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      await file.writeAsString(csv);

      // Kiểm dấu UTF-8 ở mức **byte**: `readAsString` dùng bộ giải mã UTF-8,
      // mà bộ này tự cắt dấu BOM đi — đọc bằng chuỗi thì không bao giờ thấy
      // nó, kể cả khi tệp có.
      final bytes = await file.readAsBytes();
      expect(
        bytes.take(3),
        [0xEF, 0xBB, 0xBF],
        reason: 'Thiếu dấu UTF-8 thì Excel đọc chữ có dấu thành ký tự lạ',
      );

      final readBack = await file.readAsString();
      expect(readBack, csv.replaceFirst(CsvExport.utf8Bom, ''));
      expect(readBack, contains('"Ăn lẩu tất niên; có cả bia"'));
      expect(
        readBack.split('\r\n').where((line) => line.isNotEmpty),
        hasLength(3),
        reason: '1 dòng tiêu đề + 2 người',
      );
    });
  });
}

/// Dựng bản ghi hóa đơn từ trạng thái form, qua đúng split engine app dùng.
Bill _bill(BillFormState form, Map<String, String> names) {
  final result = computeSplit(form.toSplitInput());
  expect(result.isValid, isTrue, reason: 'Lỗi chia: ${result.errors}');
  return form.toBill(result, names);
}

BillItem _item(
  String id,
  String name,
  int price,
  int order,
  List<String> userIds,
) => BillItem(
  id: id,
  name: name,
  unitPrice: price,
  sortOrder: order,
  participants: [
    for (final memberId in userIds) ItemParticipant(memberId: memberId),
  ],
);
