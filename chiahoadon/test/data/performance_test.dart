import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/stats_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/domain/models/bill_filter.dart';
import 'package:chiahoadon/domain/models/enums.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/split/split_engine.dart';
import 'package:chiahoadon/domain/split/split_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

/// Kiểm tra hiệu năng với khối lượng dữ liệu thật (NFR-3, NFR-4).
///
/// Ngưỡng đặt rộng rãi vì máy chạy test có thể chậm hoặc đang bận; mục đích là
/// bắt những sai lầm **về bậc độ lớn** — truy vấn N+1, thiếu chỉ mục, tải cả
/// bảng lên bộ nhớ — chứ không phải đo chính xác từng mili giây.
void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late List<Member> members;

  setUp(() async {
    database = await DbTestHelper.openDb();

    members = [
      for (var i = 0; i < 8; i++) DbTestHelper.member('Người $i'),
    ];
    for (final member in members) {
      await MemberDao(database).insert(member);
    }
  });

  tearDown(() async {
    await database.close();
  });

  /// Ghi [count] hóa đơn trải đều trong 12 tháng gần nhất.
  Future<void> seedBills(int count) async {
    final now = DateTime.now();

    for (var i = 0; i < count; i++) {
      // Số người tham gia thay đổi để dữ liệu giống thật hơn.
      final participants = members.take(2 + (i % 7)).toList();

      await BillDao(database).save(
        DbTestHelper.equalBill(
          title: 'Hóa đơn ${i + 1}',
          total: 100000 + (i % 50) * 10000,
          participants: participants,
          payer: participants.first,
          date: DateTime(now.year, now.month - (i % 12), 1 + (i % 28)),
        ),
      );
    }
  }

  group('NFR-3 — 1.000 hóa đơn', () {
    test('tải một trang 50 hóa đơn nhanh, không phụ thuộc tổng số', () async {
      await seedBills(1000);

      final watch = Stopwatch()..start();
      final page = await BillDao(database).getPage(const BillFilter());
      watch.stop();

      expect(page, hasLength(50));
      expect(
        watch.elapsedMilliseconds,
        lessThan(500),
        reason: 'Tải một trang mất ${watch.elapsedMilliseconds}ms — '
            'có thể đang truy vấn N+1 hoặc thiếu chỉ mục',
      );

      // Mỗi hóa đơn phải có sẵn người tham gia: nếu màn hình phải hỏi thêm
      // từng hóa đơn một thì danh sách sẽ giật.
      expect(page.every((bill) => bill.participants.isNotEmpty), isTrue);
    });

    test('trang cuối cũng nhanh như trang đầu', () async {
      await seedBills(1000);

      final first = Stopwatch()..start();
      await BillDao(database).getPage(const BillFilter());
      first.stop();

      final last = Stopwatch()..start();
      await BillDao(database).getPage(const BillFilter(), offset: 950);
      last.stop();

      expect(last.elapsedMilliseconds, lessThan(500));
    });

    test('tìm kiếm trên 1.000 hóa đơn vẫn nhanh', () async {
      await seedBills(1000);

      final watch = Stopwatch()..start();
      final found = await BillDao(database).getPage(
        const BillFilter(query: 'hoa don 7'),
      );
      watch.stop();

      expect(found, isNotEmpty);
      expect(
        watch.elapsedMilliseconds,
        lessThan(500),
        reason: 'Tìm kiếm mất ${watch.elapsedMilliseconds}ms — '
            'kiểm tra chỉ mục idx_bills_title_norm',
      );
    });

    test('thống kê gộp trên 1.000 hóa đơn chạy bằng SQL, không bằng Dart', () async {
      await seedBills(1000);

      final watch = Stopwatch()..start();
      final stats = await StatsDao(database).memberTotals(DateRange.allTime());
      final balances = await StatsDao(database).balances();
      final monthly = await StatsDao(database).monthlyTotals();
      watch.stop();

      expect(stats, hasLength(8));
      expect(monthly, isNotEmpty);
      expect(
        watch.elapsedMilliseconds,
        lessThan(1500),
        reason: 'Ba truy vấn thống kê mất ${watch.elapsedMilliseconds}ms',
      );

      // Bất biến vẫn đúng ở quy mô lớn.
      expect(balances.fold<int>(0, (sum, b) => sum + b.balance), 0);
    });

    test('đếm tổng số hóa đơn không cần tải chúng lên', () async {
      await seedBills(1000);

      final watch = Stopwatch()..start();
      final count = await BillDao(database).count(const BillFilter());
      watch.stop();

      expect(count, 1000);
      expect(watch.elapsedMilliseconds, lessThan(300));
    });
  });

  group('NFR-4 — split engine chạy trong một frame', () {
    test('hóa đơn 20 người, 30 món: dưới 16ms', () {
      final input = SplitInput(
        participants: [
          for (var i = 0; i < 20; i++) SplitParticipant(memberId: 'M$i'),
        ],
        splitType: SplitType.itemized,
        inputMode: InputMode.items,
        items: [
          for (var i = 0; i < 30; i++)
            SplitItem(
              id: 'item$i',
              unitPrice: 50000 + i * 1000,
              users: [
                for (var j = 0; j <= i % 20; j++)
                  SplitItemShare(memberId: 'M$j'),
              ],
            ),
        ],
      );

      // Chạy một lần cho JIT khởi động, rồi mới đo.
      computeSplit(input);

      final watch = Stopwatch()..start();
      final result = computeSplit(input);
      watch.stop();

      expect(result.isValid, isTrue);
      expect(result.sharesTotal, result.total);
      expect(
        watch.elapsedMicroseconds,
        lessThan(16000),
        reason: 'computeSplit mất ${watch.elapsedMicroseconds}µs — '
            'khung xem trước sẽ không theo kịp tốc độ gõ',
      );
    });

    test('gọi 100 lần liên tiếp vẫn nhanh, như khi người dùng gõ số tiền', () {
      final input = SplitInput(
        participants: [
          for (var i = 0; i < 10; i++) SplitParticipant(memberId: 'M$i'),
        ],
        splitType: SplitType.equal,
        manualTotal: 1000000,
      );

      computeSplit(input);

      final watch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        computeSplit(input.copyWith(manualTotal: 1000000 + i));
      }
      watch.stop();

      expect(
        watch.elapsedMilliseconds,
        lessThan(200),
        reason: '100 lần tính mất ${watch.elapsedMilliseconds}ms',
      );
    });
  });
}
