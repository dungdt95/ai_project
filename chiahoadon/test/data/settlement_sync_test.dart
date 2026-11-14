import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/payment_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late BillDao billDao;
  late PaymentDao paymentDao;

  late Member dung; // người ứng tiền
  late Member an;
  late Member binh;

  setUp(() async {
    database = await DbTestHelper.openDb();
    billDao = BillDao(database);
    paymentDao = PaymentDao(database);
    final memberDao = MemberDao(database);

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

  /// Hóa đơn 300.000 do Dũng ứng, chia đều 3 người -> mỗi người 100.000.
  Future<String> addBill(
    String title, {
    BillStatus status = BillStatus.unpaid,
  }) async {
    final bill = DbTestHelper.equalBill(
      title: title,
      total: 300000,
      participants: [dung, an, binh],
      payer: dung,
      status: status,
    );
    await billDao.save(bill);
    return bill.id;
  }

  Future<Map<String, Object?>> part(String billId, Member member) async {
    final rows = await database.db.query(
      'bill_participants',
      where: 'bill_id = ? AND member_id = ?',
      whereArgs: [billId, member.id],
    );
    return rows.single;
  }

  Future<String> status(String billId) async {
    final rows = await database.db.query(
      'bills',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [billId],
    );
    return rows.single['status']! as String;
  }

  group('Đồng bộ quyết toán sang hóa đơn', () {
    test('trả đủ nợ -> phần chưa trả được đánh dấu đã trả', () async {
      final b1 = await addBill('Ăn trưa');
      final b2 = await addBill('Cà phê');

      final marked = await paymentDao.insertAndSync(
        DbTestHelper.payment(from: an, to: dung, amount: 200000),
      );

      expect(marked, 2);
      for (final id in [b1, b2]) {
        final row = await part(id, an);
        expect(row['paid_amount'], 100000);
        expect(row['settled_at'], isNotNull);
        expect(row['settled_by_payment_id'], isNotNull);
        // Bình chưa trả nên hóa đơn mới chỉ ở mức một phần.
        expect((await part(id, binh))['paid_amount'], 0);
        expect(await status(id), BillStatus.partial.dbValue);
      }
    });

    test('trả một phần (còn nợ) -> không đánh dấu gì', () async {
      final b1 = await addBill('Ăn trưa');

      final marked = await paymentDao.insertAndSync(
        DbTestHelper.payment(from: an, to: dung, amount: 50000),
      );

      expect(marked, 0);
      final row = await part(b1, an);
      expect(row['paid_amount'], 0);
      expect(row['settled_at'], isNull);
      expect(row['settled_by_payment_id'], isNull);
      expect(await status(b1), BillStatus.unpaid.dbValue);
    });

    test('cả hai người nợ cùng quyết toán -> hóa đơn xong', () async {
      final b1 = await addBill('Ăn trưa');

      await paymentDao.insertAndSync(
        DbTestHelper.payment(from: an, to: dung, amount: 100000),
      );
      expect(await status(b1), BillStatus.partial.dbValue);

      await paymentDao.insertAndSync(
        DbTestHelper.payment(from: binh, to: dung, amount: 100000),
      );
      expect(await status(b1), BillStatus.settled.dbValue);
    });

    test('người ứng tiền không bị đánh dấu', () async {
      final b1 = await addBill('Ăn trưa');

      // Dũng được cho là còn dư (+200.000) nên sẽ kích hoạt đồng bộ.
      await paymentDao.insertAndSync(
        DbTestHelper.payment(from: dung, to: an, amount: 1000),
      );

      final row = await part(b1, dung);
      expect(row['paid_amount'], 0);
      expect(row['settled_at'], isNull);
      expect(row['settled_by_payment_id'], isNull);
    });

    test('hóa đơn nháp và đã xóa bị bỏ qua', () async {
      final draft = await addBill('Nháp', status: BillStatus.draft);
      final deleted = await addBill('Đã xóa');
      await billDao.softDelete(deleted);
      final live = await addBill('Hiệu lực');

      // Chỉ hóa đơn hiệu lực tính vào nợ: 100.000.
      final marked = await paymentDao.insertAndSync(
        DbTestHelper.payment(from: an, to: dung, amount: 100000),
      );

      expect(marked, 1);
      expect((await part(live, an))['paid_amount'], 100000);
      expect((await part(draft, an))['paid_amount'], 0);
      expect((await part(deleted, an))['paid_amount'], 0);
      expect(await status(draft), BillStatus.draft.dbValue);
    });

    test(
      'xóa giao dịch hoàn tác dấu do quyết toán, giữ dấu thủ công',
      () async {
        final manualPartial = await addBill('Trả một phần tay');
        final manualFull = await addBill('Trả đủ tay');
        final untouched = await addBill('Chưa trả');

        await billDao.updateParticipantPayment(
          billId: manualPartial,
          memberId: an.id,
          paidAmount: 40000,
          isSettled: false,
        );
        await billDao.updateParticipantPayment(
          billId: manualFull,
          memberId: an.id,
          paidAmount: 100000,
          isSettled: true,
        );

        final payment = DbTestHelper.payment(
          from: an,
          to: dung,
          amount: 300000,
        );
        final marked = await paymentDao.insertAndSync(payment);
        expect(marked, 2); // manualFull đã đủ nên không bị đụng tới
        expect((await part(manualPartial, an))['paid_amount'], 100000);
        expect((await part(untouched, an))['paid_amount'], 100000);

        await paymentDao.deleteAndRevert(payment.id);

        final partial = await part(manualPartial, an);
        expect(partial['paid_amount'], 40000);
        expect(partial['settled_at'], isNull);
        expect(partial['settled_by_payment_id'], isNull);
        expect(await status(manualPartial), BillStatus.partial.dbValue);

        final full = await part(manualFull, an);
        expect(full['paid_amount'], 100000);
        expect(full['settled_at'], isNotNull);

        final none = await part(untouched, an);
        expect(none['paid_amount'], 0);
        expect(none['settled_at'], isNull);
        expect(await status(untouched), BillStatus.unpaid.dbValue);
      },
    );

    test(
      'sửa tay sau đồng bộ gỡ dấu; xóa giao dịch không hoàn tác dòng đó',
      () async {
        final b1 = await addBill('Ăn trưa');
        final b2 = await addBill('Cà phê');

        final payment = DbTestHelper.payment(
          from: an,
          to: dung,
          amount: 200000,
        );
        await paymentDao.insertAndSync(payment);

        await billDao.updateParticipantPayment(
          billId: b1,
          memberId: an.id,
          paidAmount: 100000,
          isSettled: true,
        );
        expect((await part(b1, an))['settled_by_payment_id'], isNull);

        await paymentDao.deleteAndRevert(payment.id);

        expect((await part(b1, an))['paid_amount'], 100000);
        expect((await part(b1, an))['settled_at'], isNotNull);
        expect((await part(b2, an))['paid_amount'], 0);
        expect((await part(b2, an))['settled_at'], isNull);
      },
    );
  });
}
