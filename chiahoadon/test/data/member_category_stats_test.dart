import 'package:chiahoadon/core/utils/date_formatter.dart';
import 'package:chiahoadon/data/dao/bill_dao.dart';
import 'package:chiahoadon/data/dao/category_dao.dart';
import 'package:chiahoadon/data/dao/member_dao.dart';
import 'package:chiahoadon/data/dao/stats_dao.dart';
import 'package:chiahoadon/data/database/app_database.dart';
import 'package:chiahoadon/data/repositories/stats_repository.dart';
import 'package:chiahoadon/domain/models/expense_category.dart';
import 'package:chiahoadon/domain/models/member.dart';
import 'package:chiahoadon/domain/stats/stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_helper.dart';

/// Tổng chi từng thành viên bóc theo danh mục (SPEC FR-7.13).
///
/// Điều quan trọng nhất ở đây: tổng các dòng của một người phải khớp đúng tổng
/// chi của người đó ở bảng xếp hạng. Hai con số lệch nhau thì người dùng không
/// biết tin cái nào.
void main() {
  setUpAll(DbTestHelper.initFfi);

  late AppDatabase database;
  late StatsDao stats;
  late StatsRepository repository;
  late Member an;
  late Member binh;
  late List<ExpenseCategory> categories;

  setUp(() async {
    database = await DbTestHelper.openDb();
    stats = StatsDao(database);
    repository = StatsRepository(stats, MemberDao(database));

    an = DbTestHelper.member('An');
    binh = DbTestHelper.member('Bình');
    for (final member in [an, binh]) {
      await MemberDao(database).insert(member);
    }

    categories = await CategoryDao(database).getAll();
  });

  tearDown(() async {
    await database.close();
  });

  /// Hóa đơn chia đều, có gán danh mục.
  Future<void> addBill({
    required int total,
    required List<Member> participants,
    String? categoryId,
    DateTime? date,
  }) async {
    final base = DbTestHelper.equalBill(
      title: 'Hóa đơn',
      total: total,
      participants: participants,
      payer: participants.first,
      date: date,
    );
    await BillDao(database).save(base.copyWith(categoryId: categoryId));
  }

  group('Truy vấn chéo thành viên × danh mục', () {
    test('tách đúng tiền của mỗi người trong mỗi danh mục', () async {
      final food = categories[0];
      final travel = categories[1];

      // An + Bình ăn 300.000 → mỗi người 150.000
      await addBill(
        total: 300000,
        participants: [an, binh],
        categoryId: food.id,
      );
      // Chỉ An đi lại 100.000
      await addBill(
        total: 100000,
        participants: [an],
        categoryId: travel.id,
      );

      final rows = await stats.memberCategoryTotals(DateRange.allTime());

      int amountOf(Member member, ExpenseCategory category) => rows
          .firstWhere(
            (row) => row.memberId == member.id && row.categoryId == category.id,
          )
          .total;

      expect(amountOf(an, food), 150000);
      expect(amountOf(an, travel), 100000);
      expect(amountOf(binh, food), 150000);
      expect(
        rows.where((row) => row.memberId == binh.id),
        hasLength(1),
        reason: 'Bình không đi lại nên không có dòng nào cho danh mục đó',
      );
    });

    test('gộp nhiều hóa đơn cùng danh mục vào một dòng', () async {
      final food = categories[0];

      await addBill(total: 100000, participants: [an], categoryId: food.id);
      await addBill(total: 250000, participants: [an], categoryId: food.id);

      final rows = await stats.memberCategoryTotals(DateRange.allTime());

      expect(rows, hasLength(1));
      expect(rows.first.total, 350000);
      expect(rows.first.billCount, 2);
    });

    test('hóa đơn chưa chọn danh mục vẫn được tính, gọi là "Chưa phân loại"',
        () async {
      await addBill(total: 100000, participants: [an]);

      final rows = await stats.memberCategoryTotals(DateRange.allTime());

      expect(rows, hasLength(1));
      expect(rows.first.categoryId, isNull);
      expect(rows.first.categoryName, 'Chưa phân loại');
      expect(
        rows.first.total,
        100000,
        reason: 'Bỏ qua hóa đơn chưa phân loại là làm mất tiền khỏi báo cáo',
      );
    });

    test('lọc đúng theo kỳ', () async {
      final food = categories[0];

      await addBill(
        total: 100000,
        participants: [an],
        categoryId: food.id,
        date: DateTime(2026, 10, 1),
      );
      await addBill(
        total: 900000,
        participants: [an],
        categoryId: food.id,
        date: DateTime(2026, 8, 1),
      );

      final october = await stats.memberCategoryTotals(
        DateRange.thisMonth(DateTime(2026, 10, 15)),
      );

      expect(october, hasLength(1));
      expect(october.first.total, 100000);
    });

    test('chưa có hóa đơn nào thì trả danh sách rỗng', () async {
      expect(await stats.memberCategoryTotals(DateRange.allTime()), isEmpty);
    });
  });

  group('★ Khớp với bảng xếp hạng thành viên', () {
    test('tổng các danh mục của một người bằng tổng chi của người đó', () async {
      // Nhiều danh mục, nhiều người, số lẻ để phần dư rơi vào đâu đó.
      for (var i = 0; i < 6; i++) {
        await addBill(
          total: 100000 + i * 33333,
          participants: i.isEven ? [an, binh] : [an],
          categoryId: categories[i % categories.length].id,
        );
      }

      final ranking = await stats.memberTotals(DateRange.allTime());
      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;

      for (final member in ranking) {
        final breakdown = breakdowns.firstWhere(
          (each) => each.memberId == member.memberId,
        );

        expect(
          breakdown.total,
          member.totalSpent,
          reason: '${member.memberName}: bóc theo danh mục ra '
              '${breakdown.total} nhưng xếp hạng ghi ${member.totalSpent}',
        );
      }
    });
  });

  group('Gom theo người', () {
    test('mỗi người một khối, nhiều tiền đứng trước', () async {
      final food = categories[0];
      final travel = categories[1];

      // Bình chi nhiều hơn An.
      await addBill(total: 100000, participants: [an], categoryId: food.id);
      await addBill(total: 500000, participants: [binh], categoryId: food.id);
      await addBill(total: 200000, participants: [binh], categoryId: travel.id);

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;

      expect(breakdowns, hasLength(2));
      expect(breakdowns.first.memberName, 'Bình');
      expect(breakdowns.first.total, 700000);
      expect(breakdowns.last.memberName, 'An');
    });

    test('trong một người, danh mục nhiều tiền đứng trước', () async {
      final food = categories[0];
      final travel = categories[1];

      await addBill(total: 100000, participants: [an], categoryId: food.id);
      await addBill(total: 300000, participants: [an], categoryId: travel.id);

      final breakdown =
          (await repository.memberBreakdowns(DateRange.allTime()))
              .valueOrNull!
              .first;

      expect(breakdown.rows.first.categoryId, travel.id);
      expect(breakdown.top!.total, 300000);
    });

    test('tỷ trọng cộng lại bằng 1', () async {
      final food = categories[0];
      final travel = categories[1];

      await addBill(total: 100000, participants: [an], categoryId: food.id);
      await addBill(total: 300000, participants: [an], categoryId: travel.id);

      final breakdown =
          (await repository.memberBreakdowns(DateRange.allTime()))
              .valueOrNull!
              .first;

      final sum = breakdown.rows
          .map(breakdown.ratioOf)
          .fold<double>(0, (total, ratio) => total + ratio);

      expect(sum, closeTo(1.0, 0.0001));
      expect(breakdown.ratioOf(breakdown.rows.first), closeTo(0.75, 0.0001));
    });

    test('người chưa chi gì thì không có khối nào', () async {
      await addBill(
        total: 100000,
        participants: [an],
        categoryId: categories[0].id,
      );

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;

      expect(breakdowns, hasLength(1));
      expect(breakdowns.first.memberName, 'An');
    });
  });

  group('Lật bảng: một danh mục, nhiều người (FR-7.13)', () {
    test('lọc đúng người có chi trong danh mục đang chọn', () async {
      final food = categories[0];
      final travel = categories[1];

      await addBill(total: 300000, participants: [an], categoryId: food.id);
      await addBill(total: 200000, participants: [an], categoryId: travel.id);
      await addBill(total: 500000, participants: [binh], categoryId: food.id);

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;

      final inFood = membersInCategory(breakdowns, categoryId: food.id);
      expect(inFood.map((row) => row.memberName), ['Bình', 'An']);
      expect(inFood.first.total, 500000);

      final inTravel = membersInCategory(breakdowns, categoryId: travel.id);
      expect(
        inTravel.map((row) => row.memberName),
        ['An'],
        reason: 'Bình không chi gì cho đi lại nên không có dòng nào',
      );
    });

    test('gộp tất cả danh mục thì bằng tổng chi của mỗi người', () async {
      await addBill(
        total: 300000,
        participants: [an],
        categoryId: categories[0].id,
      );
      await addBill(
        total: 200000,
        participants: [an],
        categoryId: categories[1].id,
      );

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;
      final all = membersInCategory(breakdowns, allCategories: true);

      expect(all, hasLength(1));
      expect(all.first.total, 500000);
      expect(all.first.billCount, 2, reason: 'cộng cả số hóa đơn của hai dòng');
    });

    test('danh mục chưa phân loại tìm được bằng id null', () async {
      await addBill(total: 100000, participants: [an]);
      await addBill(
        total: 900000,
        participants: [binh],
        categoryId: categories[0].id,
      );

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;
      final rows = membersInCategory(breakdowns);

      expect(rows, hasLength(1));
      expect(rows.first.memberName, 'An');
      expect(rows.first.categoryName, 'Chưa phân loại');
    });

    test('người bị ẩn biến mất khỏi kết quả', () async {
      final food = categories[0];
      await addBill(total: 300000, participants: [an], categoryId: food.id);
      await addBill(total: 500000, participants: [binh], categoryId: food.id);

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;
      final rows = membersInCategory(
        breakdowns,
        categoryId: food.id,
        hidden: {binh.id},
      );

      expect(rows, hasLength(1));
      expect(rows.first.memberName, 'An');
      expect(
        rows.fold<int>(0, (sum, row) => sum + row.total),
        300000,
        reason: 'người bị ẩn phải ra khỏi cả tổng, nếu không phần trăm sẽ '
            'không cộng lại thành 100%',
      );
    });

    test('ẩn hết thì trả danh sách rỗng chứ không lỗi', () async {
      await addBill(
        total: 300000,
        participants: [an],
        categoryId: categories[0].id,
      );

      final breakdowns =
          (await repository.memberBreakdowns(DateRange.allTime())).valueOrNull!;

      expect(
        membersInCategory(breakdowns, allCategories: true, hidden: {an.id}),
        isEmpty,
      );
    });
  });
}
