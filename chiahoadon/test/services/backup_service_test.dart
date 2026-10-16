import 'dart:convert';

import 'package:chiahoadon/core/constants/app_constants.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/group_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/payment_dao.dart';
import 'package:chiahoadon/data/dao/settings_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/db_test_helper.dart';

/// Sao lưu và phục hồi (SPEC FR-8.4, FR-8.5).
///
/// Đây là lưới an toàn duy nhất của app: không có cloud, mất máy là mất sạch
/// (PLAN §2, rủi ro R3). Nên vòng "sao lưu → xóa sạch → phục hồi" phải được
/// kiểm tới tận từng con số.
void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late BackupService backup;
  late Member dung;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await DbTestHelper.openDb();
    backup = BackupService(database);

    dung = DbTestHelper.member('Dũng');
    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [dung, an, binh]) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Dựng một bộ dữ liệu đủ các loại bản ghi.
  Future<void> seed() async {
    await GroupDao(database).save(
      DbTestHelper.group('Team Dev', members: [dung, an, binh]),
    );

    final bill = DbTestHelper.equalBill(
      title: 'Ăn lẩu tất niên',
      total: 900000,
      participants: [dung, an, binh],
      payer: dung,
    );
    await BillDao(database).save(bill);
    await BillDao(database).updateParticipantPayment(
      billId: bill.id,
      memberId: an.id,
      paidAmount: 300000,
      isSettled: true,
    );

    await BillDao(database).save(
      DbTestHelper.equalBill(
        title: 'Cà phê',
        total: 60000,
        participants: [an, binh],
        payer: an,
      ).copyWith(
        splitType: SplitType.itemized,
        inputMode: InputMode.items,
        items: [
          DbTestHelper.item(
            name: 'Cà phê sữa',
            unitPrice: 30000,
            users: [an, binh],
          ),
        ],
      ),
    );

    await PaymentDao(database).insert(
      DbTestHelper.payment(from: binh, to: dung, amount: 300000),
    );
  }

  group('★ Vòng sao lưu → xóa sạch → phục hồi', () {
    test('mọi hóa đơn và số tiền y nguyên sau khi phục hồi', () async {
      await seed();

      final before = await BillDao(database).getPage(const BillFilter());
      final beforeBalances = {
        for (final bill in before) bill.title: bill.totalAmount,
      };
      expect(before, hasLength(2));

      // 1 — sao lưu
      final exported = await backup.export();
      expect(exported.isOk, isTrue);
      final json = exported.valueOrNull!;

      // 2 — xóa sạch
      await backup.resetAll();
      expect(await BillDao(database).count(const BillFilter()), 0);
      expect(await MemberDao(database).getAll(), hasLength(1));
      expect(await GroupDao(database).getAll(), isEmpty);
      expect(await PaymentDao(database).getAll(), isEmpty);

      // 3 — phục hồi
      final restored = await backup.restore(json);
      expect(restored.isOk, isTrue, reason: '${restored.errorOrNull}');

      // 4 — đối chiếu
      final after = await BillDao(database).getPage(const BillFilter());
      expect(after, hasLength(2));
      expect(
        {for (final bill in after) bill.title: bill.totalAmount},
        beforeBalances,
      );

      expect(await MemberDao(database).getAll(), hasLength(4));
      expect(await GroupDao(database).getAll(), hasLength(1));
      expect(await PaymentDao(database).getAll(), hasLength(1));
    });

    test('quan hệ con được giữ nguyên: người tham gia, món, đã trả', () async {
      await seed();

      final json = (await backup.export()).valueOrNull!;
      await backup.resetAll();
      await backup.restore(json);

      final bills = await BillDao(database).getPage(const BillFilter());
      final hotpot = bills.firstWhere((b) => b.title == 'Ăn lẩu tất niên');
      final full = await BillDao(database).getById(hotpot.id);

      expect(full!.participants, hasLength(3));
      expect(full.payers, hasLength(1));
      expect(full.payers.first.memberId, dung.id);

      // Bất biến cốt lõi vẫn đúng sau khi phục hồi.
      expect(full.totalShares, full.totalAmount);

      // Trạng thái đã trả của An được giữ.
      expect(full.participantOf(an.id)!.paidAmount, 300000);
      expect(full.participantOf(an.id)!.settledAt, isNotNull);

      final coffee = await BillDao(database).getById(
        bills.firstWhere((b) => b.title == 'Cà phê').id,
      );
      expect(coffee!.items, hasLength(1));
      expect(coffee.items.first.name, 'Cà phê sữa');
      expect(coffee.items.first.participants, hasLength(2));
    });

    test('cài đặt cũng được sao lưu', () async {
      await SettingsDao(database).setRoundingUnit(5000);
      await SettingsDao(database).setRoundingMode(RoundingMode.nearest);

      final json = (await backup.export()).valueOrNull!;
      await backup.resetAll();
      expect(
        await SettingsDao(database).roundingUnit(),
        AppConstants.defaultRoundingUnit,
      );

      await backup.restore(json);

      expect(await SettingsDao(database).roundingUnit(), 5000);
      expect(
        await SettingsDao(database).roundingMode(),
        RoundingMode.nearest,
      );
    });

    test('phục hồi hai lần liên tiếp cho cùng kết quả', () async {
      await seed();
      final json = (await backup.export()).valueOrNull!;

      await backup.restore(json);
      final first = await BillDao(database).count(const BillFilter());

      await backup.restore(json);
      final second = await BillDao(database).count(const BillFilter());

      expect(first, second, reason: 'Phục hồi không được nhân đôi dữ liệu');
    });
  });

  group('Đọc trước nội dung tệp (FR-8.5)', () {
    test('cho biết trong tệp có gì trước khi ghi đè', () async {
      await seed();
      final json = (await backup.export()).valueOrNull!;

      final info = BackupService.inspect(json).valueOrNull!;

      expect(info.billCount, 2);
      expect(info.memberCount, 4);
      expect(info.groupCount, 1);
      expect(info.paymentCount, 1);
      expect(info.exportedAt, isNotNull);
      expect(info.summary, '2 hóa đơn · 4 thành viên · 1 nhóm');
      expect(info.isEmpty, isFalse);
    });

    test('tệp không phải JSON thì báo lỗi dễ hiểu', () {
      final result = BackupService.inspect('đây không phải json');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, contains('không đọc được'));
    });

    test('JSON hợp lệ nhưng không phải bản sao lưu thì báo lỗi', () {
      final result = BackupService.inspect('{"foo": "bar"}');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, contains('không phải bản sao lưu'));
    });

    test('tệp của phiên bản mới hơn thì từ chối, không đoán mò', () {
      final result = BackupService.inspect(
        jsonEncode({'format_version': 99, 'tables': <String, Object?>{}}),
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, contains('mới hơn'));
    });

    test('tệp thiếu phần dữ liệu thì báo lỗi', () {
      final result = BackupService.inspect(jsonEncode({'format_version': 1}));

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, contains('thiếu phần dữ liệu'));
    });

    test('tệp hỏng không làm mất dữ liệu đang có', () async {
      await seed();
      final before = await BillDao(database).count(const BillFilter());

      final result = await backup.restore('{"foo": "bar"}');

      expect(result.isErr, isTrue);
      expect(
        await BillDao(database).count(const BillFilter()),
        before,
        reason: 'Phục hồi thất bại thì dữ liệu cũ phải còn nguyên',
      );
    });
  });

  group('Nhắc sao lưu (FR-8.6)', () {
    test('chưa sao lưu bao giờ thì nhắc', () {
      expect(BackupService.shouldRemind(null), isTrue);
      expect(BackupService.daysSince(null), isNull);
    });

    test('vừa sao lưu thì không nhắc', () {
      final now = DateTime(2026, 10, 3);
      expect(
        BackupService.shouldRemind(now.subtract(const Duration(days: 1)), now),
        isFalse,
      );
    });

    test('quá ngưỡng thì nhắc', () {
      final now = DateTime(2026, 10, 3);
      final old = now.subtract(
        const Duration(days: AppConstants.backupReminderDays + 1),
      );

      expect(BackupService.shouldRemind(old, now), isTrue);
      expect(
        BackupService.daysSince(old, now),
        AppConstants.backupReminderDays + 1,
      );
    });
  });

  group('Tên tệp sao lưu', () {
    test('có ngày giờ để không ghi đè bản cũ', () {
      final name = BackupService.suggestedFileName(
        DateTime(2026, 10, 3, 7, 5),
      );

      expect(name, 'chiahoadon-20261003-0705.json');
    });
  });
}
