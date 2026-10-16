import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/payment_dao.dart';
import 'package:chiahoadon/data/dao/stats_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/models/payment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late MemberDao memberDao;
  late BillDao billDao;
  late StatsDao statsDao;

  late Member dung;
  late Member an;
  late Member binh;

  setUp(() async {
    database = await DbTestHelper.openDb();
    memberDao = MemberDao(database);
    billDao = BillDao(database);
    statsDao = StatsDao(database);

    dung = DbTestHelper.member('Dũng');
    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [dung, an, binh]) {
      await memberDao.insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  group('Tổng chi phí từng thành viên (SPEC FR-7.1)', () {
    test('cộng đúng phần của mỗi người qua nhiều hóa đơn', () async {
      // 300.000 chia 3 -> mỗi người 100.000
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Ăn trưa',
          total: 300000,
          participants: [dung, an, binh],
          payer: dung,
        ),
      );
      // 200.000 chia 2 -> An và Bình mỗi người 100.000
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Cà phê',
          total: 200000,
          participants: [an, binh],
          payer: an,
        ),
      );

      final stats = await statsDao.memberTotals(DateRange.allTime());
      final byId = {for (final stat in stats) stat.memberId: stat};

      expect(byId[dung.id]!.totalSpent, 100000);
      expect(byId[dung.id]!.billCount, 1);
      expect(byId[an.id]!.totalSpent, 200000);
      expect(byId[an.id]!.billCount, 2);
      expect(byId[binh.id]!.totalSpent, 200000);

      // Tổng chi của mọi người bằng tổng mọi hóa đơn.
      final sum = stats.fold<int>(0, (acc, stat) => acc + stat.totalSpent);
      expect(sum, 500000);
    });

    test('xếp giảm dần theo tổng chi', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Chỉ An',
          total: 500000,
          participants: [an],
          payer: an,
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Chỉ Bình',
          total: 100000,
          participants: [binh],
          payer: binh,
        ),
      );

      final stats = await statsDao.memberTotals(DateRange.allTime());

      expect(stats.first.memberId, an.id);
      expect(stats.first.totalSpent, 500000);
    });

    test('loại hóa đơn nháp khỏi thống kê', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Nháp',
          total: 999000,
          participants: [an],
          payer: an,
          status: BillStatus.draft,
        ),
      );

      final stats = await statsDao.memberTotals(DateRange.allTime());

      expect(stats, isEmpty);
    });

    test('loại hóa đơn đã xóa mềm', () async {
      final bill = DbTestHelper.equalBill(
        title: 'Sẽ xóa',
        total: 100000,
        participants: [an],
        payer: an,
      );
      await billDao.save(bill);
      await billDao.softDelete(bill.id);

      final stats = await statsDao.memberTotals(DateRange.allTime());

      expect(stats, isEmpty);
    });

    test('lọc đúng theo khoảng thời gian', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Tháng này',
          total: 100000,
          participants: [an],
          payer: an,
          date: DateTime.now(),
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Năm ngoái',
          total: 900000,
          participants: [an],
          payer: an,
          date: DateTime(DateTime.now().year - 1, 6, 15),
        ),
      );

      final thisMonth = await statsDao.memberTotals(DateRange.thisMonth());
      final allTime = await statsDao.memberTotals(DateRange.allTime());

      expect(thisMonth.first.totalSpent, 100000);
      expect(allTime.first.totalSpent, 1000000);
    });
  });

  group('Chi phí từng lần theo mỗi hóa đơn (SPEC FR-7.2)', () {
    test('trả về dòng thời gian, mới nhất trước', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn cũ',
          total: 100000,
          participants: [an],
          payer: an,
          date: DateTime(2026, 9, 1),
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn mới',
          total: 200000,
          participants: [an],
          payer: an,
          date: DateTime(2026, 10, 1),
        ),
      );

      final timeline = await statsDao.memberTimeline(an.id);

      expect(timeline, hasLength(2));
      expect(timeline.first.title, 'Hóa đơn mới');
      expect(timeline.first.shareAmount, 200000);
      expect(timeline.last.title, 'Hóa đơn cũ');
    });

    test('ghi nhận đúng trạng thái đã trả của từng lần', () async {
      final bill = DbTestHelper.equalBill(
        title: 'Ăn tối',
        total: 300000,
        participants: [dung, an, binh],
        payer: dung,
      );
      await billDao.save(bill);

      final anShare = bill.participantOf(an.id)!.shareAmount;
      await billDao.updateParticipantPayment(
        billId: bill.id,
        memberId: an.id,
        paidAmount: anShare,
        isSettled: true,
      );

      final anTimeline = await statsDao.memberTimeline(an.id);
      final binhTimeline = await statsDao.memberTimeline(binh.id);

      expect(anTimeline.first.isSettled, isTrue);
      expect(anTimeline.first.remaining, 0);
      expect(binhTimeline.first.isSettled, isFalse);
      expect(binhTimeline.first.remaining, 100000);
      expect(
        binhTimeline.first.paymentStatus,
        ParticipantPaymentStatus.unpaid,
      );
    });

    test('hiện cả tổng hóa đơn để so với phần của mình', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Ăn nhóm',
          total: 900000,
          participants: [dung, an, binh],
          payer: dung,
        ),
      );

      final timeline = await statsDao.memberTimeline(an.id);

      expect(timeline.first.billTotal, 900000);
      expect(timeline.first.shareAmount, 300000);
    });
  });

  group('Số dư ròng (SPEC FR-6.4)', () {
    test('tổng số dư của mọi thành viên luôn bằng 0', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Dũng trả',
          total: 900000,
          participants: [dung, an, binh],
          payer: dung,
        ),
      );

      final balances = await statsDao.balances();
      final sum = balances.fold<int>(0, (acc, b) => acc + b.balance);

      expect(sum, 0);
    });

    test('người ứng tiền là chủ nợ, người còn lại là con nợ', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Dũng trả hết',
          total: 900000,
          participants: [dung, an, binh],
          payer: dung,
        ),
      );

      final byId = {
        for (final b in await statsDao.balances()) b.memberId: b,
      };

      // Dũng ứng 900.000, tự chịu 300.000 -> còn được nhận 600.000
      expect(byId[dung.id]!.balance, 600000);
      expect(byId[dung.id]!.isCreditor, isTrue);
      expect(byId[an.id]!.balance, -300000);
      expect(byId[binh.id]!.balance, -300000);
      expect(byId[an.id]!.isDebtor, isTrue);
    });

    test('ghi nhận chuyển tiền thì số dư về 0', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Dũng trả',
          total: 900000,
          participants: [dung, an, binh],
          payer: dung,
        ),
      );

      final paymentDao = PaymentDao(database);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final debtor in [an, binh]) {
        await paymentDao.insert(
          Payment(
            id: DbTestHelper.uuid.v4(),
            fromMemberId: debtor.id,
            toMemberId: dung.id,
            amount: 300000,
            paidAt: now,
            createdAt: now,
          ),
        );
      }

      final balances = await statsDao.balances();

      expect(balances.every((b) => b.isClear), isTrue);
      expect(balances.fold<int>(0, (acc, b) => acc + b.balance), 0);
    });

    test('người ứng tiền không tham gia ăn vẫn ra số dư đúng', () async {
      // Dũng trả hộ nhưng không ăn (SPEC FR-3, quy tắc nghiệp vụ).
      final bill = DbTestHelper.equalBill(
        title: 'Dũng trả hộ',
        total: 600000,
        participants: [an, binh],
        payer: dung,
      );
      await billDao.save(bill);

      final byId = {
        for (final b in await statsDao.balances()) b.memberId: b,
      };

      expect(byId[dung.id]!.balance, 600000);
      expect(byId[dung.id]!.owed, 0);
      expect(byId[an.id]!.balance, -300000);
      expect(byId[binh.id]!.balance, -300000);
    });
  });

  group('Thống kê theo tháng & Dashboard', () {
    test('gom tổng chi theo tháng', () async {
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Tháng 9',
          total: 100000,
          participants: [an],
          payer: an,
          date: DateTime(2026, 9, 10),
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Tháng 10 lần 1',
          total: 200000,
          participants: [an],
          payer: an,
          date: DateTime(2026, 10, 1),
        ),
      );
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Tháng 10 lần 2',
          total: 300000,
          participants: [an],
          payer: an,
          date: DateTime(2026, 10, 20),
        ),
      );

      final monthly = await statsDao.monthlyTotals();
      final byKey = {for (final stat in monthly) stat.monthKey: stat};

      expect(byKey['2026-10']!.total, 500000);
      expect(byKey['2026-10']!.billCount, 2);
      expect(byKey['2026-09']!.total, 100000);
    });

    test('Dashboard: chi tháng này và tiền đang được nợ', () async {
      await memberDao.setSelf(dung.id);
      await billDao.save(
        DbTestHelper.equalBill(
          title: 'Ăn nhóm tháng này',
          total: 900000,
          participants: [dung, an, binh],
          payer: dung,
          date: DateTime.now(),
        ),
      );

      final summary = await statsDao.dashboard(dung.id);

      expect(summary.monthTotal, 300000);
      expect(summary.monthBillCount, 1);
      expect(summary.owedToMe, 600000);
      expect(summary.iOwe, 0);
      expect(summary.unsettledBillCount, 1);
    });

    test('Dashboard trả giá trị rỗng khi chưa có bản ghi "Tôi"', () async {
      final summary = await statsDao.dashboard(null);

      expect(summary.monthTotal, 0);
      expect(summary.owedToMe, 0);
    });
  });
}
