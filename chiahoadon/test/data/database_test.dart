import 'package:chiahoadon/core/constants/app_constants.dart';
import 'package:chiahoadon/core/constants/db_constants.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/category_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/settings_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/data/database/seed_data.dart';
import 'package:chiahoadon/data/repositories/bill_repository.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/bill_participant.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;

  setUp(() async {
    database = await DbTestHelper.openDb();
  });

  tearDown(() async {
    await database.close();
  });

  group('Tạo DB & dữ liệu khởi tạo (PLAN §4.3)', () {
    test('tạo đủ 12 bảng', () async {
      final rows = await database.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );
      final tables = rows.map((row) => row['name']! as String).toSet();

      expect(tables, containsAll(Tables.deletionOrder));
      expect(tables, contains(Tables.appSettings));
      expect(tables, contains(Tables.billTemplates));
    });

    test('bật khóa ngoại', () async {
      final rows = await database.db.rawQuery('PRAGMA foreign_keys');
      expect(rows.first.values.first, 1);
    });

    test('seed 7 danh mục mặc định', () async {
      final categories = await CategoryDao(database).getAll();

      expect(categories, hasLength(SeedData.categories.length));
      expect(categories.first.name, 'Ăn uống');
      expect(categories.every((c) => c.isBuiltin), isTrue);
    });

    test('seed đúng một thành viên "Tôi"', () async {
      final self = await MemberDao(database).getSelf();

      expect(self, isNotNull);
      expect(self!.name, SeedData.selfMemberName);
      expect(self.isSelf, isTrue);
    });

    test('seed cài đặt mặc định: làm tròn 1.000đ, mode up', () async {
      final settings = SettingsDao(database);

      expect(await settings.roundingUnit(), AppConstants.defaultRoundingUnit);
      expect(await settings.roundingMode(), RoundingMode.up);
      expect(await settings.themeMode(), 'system');
    });

    test('chỉ mục unique chặn hai thành viên cùng là "Tôi"', () async {
      final dao = MemberDao(database);

      await expectLater(
        dao.insert(DbTestHelper.member('Dũng', isSelf: true)),
        throwsA(anything),
      );
    });
  });

  group('MemberDao (SPEC FR-1)', () {
    test('thêm rồi đọc lại được thành viên', () async {
      final dao = MemberDao(database);
      final an = DbTestHelper.member('An');

      await dao.insert(an);
      final loaded = await dao.getById(an.id);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'An');
      expect(loaded.avatarColor, an.avatarColor);
      expect(loaded.isActive, isTrue);
    });

    test('tìm kiếm bỏ qua dấu tiếng Việt', () async {
      final dao = MemberDao(database);
      await dao.insert(DbTestHelper.member('Bình'));
      await dao.insert(DbTestHelper.member('Dũng'));

      final found = await dao.search('binh');

      expect(found, hasLength(1));
      expect(found.first.name, 'Bình');
    });

    test('phát hiện trùng tên sau khi bỏ dấu', () async {
      final dao = MemberDao(database);
      await dao.insert(DbTestHelper.member('Anh'));

      final duplicates = await dao.findByNameNorm('anh');

      expect(duplicates, hasLength(1));
    });

    test('ngừng hoạt động thì bị loại khỏi danh sách chọn', () async {
      final dao = MemberDao(database);
      final chi = DbTestHelper.member('Chi');
      await dao.insert(chi);

      await dao.setActive(chi.id, false);

      final selectable = await dao.getAll();
      final all = await dao.getAll(includeInactive: true);

      expect(selectable.any((m) => m.id == chi.id), isFalse);
      expect(all.any((m) => m.id == chi.id), isTrue);
    });

    test('chuyển "Tôi" sang người khác không vi phạm chỉ mục unique', () async {
      final dao = MemberDao(database);
      final an = DbTestHelper.member('An');
      await dao.insert(an);

      await dao.setSelf(an.id);

      final self = await dao.getSelf();
      expect(self!.id, an.id);

      final selfCount = await database.db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM ${Tables.members} WHERE is_self = 1',
      );
      expect(selfCount.first['cnt'], 1);
    });

    test('thành viên chưa có hóa đơn thì không bị tham chiếu', () async {
      final dao = MemberDao(database);
      final an = DbTestHelper.member('An');
      await dao.insert(an);

      expect(await dao.hasAnyReference(an.id), isFalse);
      expect(await dao.countBills(an.id), 0);
    });
  });

  group('BillDao — lưu và đọc hóa đơn (SPEC FR-3)', () {
    test('lưu hóa đơn chia đều rồi đọc lại đủ quan hệ', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final dung = DbTestHelper.member('Dũng');
      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      for (final member in [dung, an, binh]) {
        await memberDao.insert(member);
      }

      final bill = DbTestHelper.equalBill(
        title: 'Ăn lẩu tất niên',
        total: 1000000,
        participants: [dung, an, binh],
        payer: dung,
      );
      await billDao.save(bill);

      final loaded = await billDao.getById(bill.id);

      expect(loaded, isNotNull);
      expect(loaded!.title, 'Ăn lẩu tất niên');
      expect(loaded.totalAmount, 1000000);
      expect(loaded.participants, hasLength(3));
      expect(loaded.payers, hasLength(1));
      expect(loaded.payers.first.memberId, dung.id);

      // Bất biến cốt lõi: tổng các phần bằng tổng hóa đơn (SPEC FR-4).
      expect(loaded.totalShares, loaded.totalAmount);
    });

    test('lưu hóa đơn theo món, đọc lại đúng người dùng từng món', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      final chi = DbTestHelper.member('Chi');
      for (final member in [an, binh, chi]) {
        await memberDao.insert(member);
      }

      final base = DbTestHelper.equalBill(
        title: 'Ăn lẩu theo món',
        total: 750000,
        participants: [an, binh, chi],
        payer: an,
      );
      final bill = base.copyWith(
        splitType: SplitType.itemized,
        inputMode: InputMode.items,
        items: [
          DbTestHelper.item(
            name: 'Phở bò',
            unitPrice: 60000,
            users: [an, binh],
          ),
          DbTestHelper.item(
            name: 'Bia Tiger',
            unitPrice: 20000,
            sortOrder: 1,
            users: [an, binh],
          ),
          DbTestHelper.item(
            name: 'Nước ép',
            unitPrice: 50000,
            sortOrder: 2,
            users: [chi],
          ),
        ],
      );

      await billDao.save(bill);
      final loaded = await billDao.getById(bill.id);

      expect(loaded!.items, hasLength(3));
      // Giá × số người: 60.000×2, 20.000×2, 50.000×1
      expect(loaded.items.map((i) => i.amount).toList(), [120000, 40000, 50000]);
      expect(loaded.items.fold(0, (sum, i) => sum + i.amount), 210000);

      final beer = loaded.items.firstWhere((i) => i.name == 'Bia Tiger');
      expect(beer.participants, hasLength(2));
      expect(beer.includes(chi.id), isFalse);
      expect(beer.includes(an.id), isTrue);
    });

    test('lưu lại hóa đơn không để lại món mồ côi', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      await memberDao.insert(an);

      final bill = DbTestHelper.equalBill(
        title: 'Cà phê',
        total: 100000,
        participants: [an],
        payer: an,
      ).copyWith(
        items: [DbTestHelper.item(name: 'Cà phê sữa', unitPrice: 100000, users: [an])],
      );
      await billDao.save(bill);

      // Lưu lần hai với danh sách món khác: bản ghi cũ phải bị dọn sạch.
      await billDao.save(
        bill.copyWith(
          items: [DbTestHelper.item(name: 'Trà đào', unitPrice: 100000, users: [an])],
        ),
      );

      final items = await database.db.query(Tables.billItems);
      final links = await database.db.query(Tables.billItemParticipants);

      expect(items, hasLength(1));
      expect(items.first['name'], 'Trà đào');
      expect(links, hasLength(1));
    });

    test('xóa mềm rồi hoàn tác được', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      await memberDao.insert(an);

      final bill = DbTestHelper.equalBill(
        title: 'Trà sữa',
        total: 60000,
        participants: [an],
        payer: an,
      );
      await billDao.save(bill);

      await billDao.softDelete(bill.id);
      expect(await billDao.count(const BillFilter()), 0);

      await billDao.restore(bill.id);
      expect(await billDao.count(const BillFilter()), 1);
    });

    test('lọc theo thành viên tham gia', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      await memberDao.insert(an);
      await memberDao.insert(binh);

      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Chỉ An',
          total: 50000,
          participants: [an],
          payer: an,
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'An và Bình',
          total: 100000,
          participants: [an, binh],
          payer: an,
        ),
      );

      final ofBinh = await billDao.getPage(BillFilter(memberId: binh.id));

      expect(ofBinh, hasLength(1));
      expect(ofBinh.first.title, 'An và Bình');
    });

    test('đánh dấu đã trả thì trạng thái hóa đơn tự chuyển', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final dung = DbTestHelper.member('Dũng');
      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      for (final member in [dung, an, binh]) {
        await memberDao.insert(member);
      }

      final bill = DbTestHelper.equalBill(
        title: 'Ăn trưa',
        total: 300000,
        participants: [dung, an, binh],
        payer: dung,
      );
      await billDao.save(bill);

      final anShare = bill.participantOf(an.id)!.shareAmount;

      // An trả một phần -> partial
      await billDao.updateParticipantPayment(
        billId: bill.id,
        memberId: an.id,
        paidAmount: anShare - 10000,
        isSettled: false,
      );
      expect((await billDao.getById(bill.id))!.status, BillStatus.partial);

      // An trả hết, Bình trả hết -> settled (Dũng là người ứng, không tính nợ)
      await billDao.updateParticipantPayment(
        billId: bill.id,
        memberId: an.id,
        paidAmount: anShare,
        isSettled: true,
      );
      await billDao.updateParticipantPayment(
        billId: bill.id,
        memberId: binh.id,
        paidAmount: bill.participantOf(binh.id)!.shareAmount,
        isSettled: true,
      );
      expect((await billDao.getById(bill.id))!.status, BillStatus.settled);
    });

    test('settleAll đánh dấu mọi người đã trả', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      await memberDao.insert(an);
      await memberDao.insert(binh);

      final bill = DbTestHelper.equalBill(
        title: 'Taxi',
        total: 150000,
        participants: [an, binh],
        payer: an,
      );
      await billDao.save(bill);

      await billDao.settleAll(bill.id);
      final loaded = await billDao.getById(bill.id);

      expect(loaded!.status, BillStatus.settled);
      expect(
        loaded.participants.every((p) => p.paidAmount == p.shareAmount),
        isTrue,
      );
    });
  });

  group('BillRepository.validate — bất biến trước khi ghi', () {
    test('chặn hóa đơn có tổng các phần lệch tổng hóa đơn', () async {
      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');

      final bill = DbTestHelper.equalBill(
        title: 'Lệch',
        total: 100000,
        participants: [an, binh],
        payer: an,
      );
      // Cố tình làm lệch 1 đồng.
      final broken = bill.copyWith(
        participants: [
          bill.participants.first.copyWith(shareAmount: 49999),
          bill.participants.last,
        ],
      );

      final error = BillRepository.validate(broken);

      expect(error, isNotNull);
      expect(error!.message, contains('không khớp tổng hóa đơn'));
    });

    test('chặn hóa đơn không có người tham gia', () {
      final an = DbTestHelper.member('An');
      final bill = DbTestHelper.equalBill(
        title: 'Rỗng',
        total: 100000,
        participants: [an],
        payer: an,
      ).copyWith(participants: []);

      expect(BillRepository.validate(bill)?.message, contains('người tham gia'));
    });

    test('chặn tổng tiền ứng trước khác tổng hóa đơn', () {
      final an = DbTestHelper.member('An');
      final bill = DbTestHelper.equalBill(
        title: 'Ứng sai',
        total: 100000,
        participants: [an],
        payer: an,
      ).copyWith(payers: [BillPayer(memberId: an.id, paidAmount: 90000)]);

      expect(BillRepository.validate(bill)?.message, contains('ứng trước'));
    });

    test('hóa đơn hợp lệ thì không có lỗi', () {
      final an = DbTestHelper.member('An');
      final binh = DbTestHelper.member('Bình');
      final bill = DbTestHelper.equalBill(
        title: 'Hợp lệ',
        total: 1000000,
        participants: [an, binh],
        payer: an,
      );

      expect(BillRepository.validate(bill), isNull);
    });
  });

  group('Reset dữ liệu (SPEC FR-9.6)', () {
    test('xóa hết hóa đơn nhưng nạp lại dữ liệu khởi tạo', () async {
      final memberDao = MemberDao(database);
      final billDao = BillDao(database);

      final an = DbTestHelper.member('An');
      await memberDao.insert(an);
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Sẽ bị xóa',
          total: 50000,
          participants: [an],
          payer: an,
        ),
      );

      await database.resetAll();

      expect(await billDao.count(const BillFilter()), 0);
      expect(await CategoryDao(database).getAll(), hasLength(7));
      expect(await memberDao.getSelf(), isNotNull);
      expect(await memberDao.getAll(), hasLength(1));
    });
  });
}
