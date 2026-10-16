import 'dart:math';

import 'package:chiahoadon/domain/settlement/debt_simplifier.dart';
import 'package:chiahoadon/domain/stats/stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test thuật toán tối thiểu hóa giao dịch (SPEC FR-6.5, PLAN §8.2).
void main() {
  MemberBalance balance(String id, int amount) => MemberBalance(
    memberId: id,
    memberName: id,
    avatarColor: 0,
    advanced: amount > 0 ? amount : 0,
    owed: amount < 0 ? -amount : 0,
    sent: 0,
    received: 0,
  );

  group('TC-S1 → TC-S3 · các trường hợp cụ thể', () {
    test('TC-S1 · An +500k, Bình −300k, Chi −200k → đúng 2 giao dịch', () {
      final transfers = DebtSimplifier.simplify([
        balance('An', 500000),
        balance('Bình', -300000),
        balance('Chi', -200000),
      ]);

      expect(transfers, hasLength(2));
      expect(
        transfers.map((t) => '${t.fromName}->${t.toName}:${t.amount}'),
        containsAll(['Bình->An:300000', 'Chi->An:200000']),
      );
    });

    test('TC-S2 · mọi người đã cân bằng thì không cần giao dịch nào', () {
      final transfers = DebtSimplifier.simplify([
        balance('An', 0),
        balance('Bình', 0),
        balance('Chi', 0),
        balance('Dũng', 0),
      ]);

      expect(transfers, isEmpty);
    });

    test('TC-S3 · 5 người lệch nhau → tối đa 4 giao dịch, sau đó cân bằng', () {
      final balances = [
        balance('A', 1000000),
        balance('B', 500000),
        balance('C', -700000),
        balance('D', -500000),
        balance('E', -300000),
      ];

      final transfers = DebtSimplifier.simplify(balances);

      expect(transfers.length, lessThanOrEqualTo(4));
      _expectSettles(balances, transfers);
    });

    test('một người nợ nhiều người khác', () {
      final balances = [
        balance('Nợ', -900000),
        balance('A', 300000),
        balance('B', 300000),
        balance('C', 300000),
      ];

      final transfers = DebtSimplifier.simplify(balances);

      expect(transfers, hasLength(3));
      expect(transfers.every((t) => t.fromName == 'Nợ'), isTrue);
      _expectSettles(balances, transfers);
    });

    test('một người trả hộ cả nhóm', () {
      final balances = [
        balance('Dũng', 600000),
        balance('An', -300000),
        balance('Bình', -300000),
      ];

      final transfers = DebtSimplifier.simplify(balances);

      expect(transfers, hasLength(2));
      expect(transfers.every((t) => t.toName == 'Dũng'), isTrue);
    });

    test('chỉ có chủ nợ mà không có con nợ thì không gợi ý gì', () {
      expect(DebtSimplifier.simplify([balance('An', 500000)]), isEmpty);
    });

    test('danh sách rỗng', () {
      expect(DebtSimplifier.simplify(const []), isEmpty);
    });

    test('kết quả tái lập được: gọi hai lần cho cùng danh sách', () {
      final balances = [
        balance('A', 500000),
        balance('B', 500000),
        balance('C', -500000),
        balance('D', -500000),
      ];

      expect(
        DebtSimplifier.simplify(balances),
        DebtSimplifier.simplify(balances),
      );
    });
  });

  group('TC-S4 · property test', () {
    test('1.000 bộ số dư ngẫu nhiên: luôn cân bằng được và ≤ n−1 giao dịch', () {
      final random = Random(20261003);

      for (var iteration = 0; iteration < 1000; iteration++) {
        final count = 2 + random.nextInt(19);
        final amounts = List.generate(
          count,
          (_) => random.nextInt(2000001) - 1000000,
        );

        // Ép tổng về 0 — đó là bất biến mà dữ liệu thật luôn thỏa mãn.
        final sum = amounts.fold<int>(0, (a, b) => a + b);
        amounts[0] -= sum;

        final balances = [
          for (var i = 0; i < count; i++) balance('M$i', amounts[i]),
        ];

        expect(
          DebtSimplifier.balanceSum(balances),
          0,
          reason: 'Lần $iteration: dữ liệu dựng sai',
        );

        final transfers = DebtSimplifier.simplify(balances);
        final nonZero = balances.where((b) => b.balance != 0).length;

        if (nonZero > 0 && transfers.length > nonZero - 1) {
          fail(
            'Lần $iteration: ${transfers.length} giao dịch cho $nonZero người '
            'có số dư — vượt ngưỡng n−1',
          );
        }

        _expectSettles(balances, transfers, iteration: iteration);
      }
    });

    test('tổng tiền chuyển bằng tổng số dư dương', () {
      final random = Random(987654);

      for (var iteration = 0; iteration < 500; iteration++) {
        final count = 2 + random.nextInt(10);
        final amounts = List.generate(
          count,
          (_) => random.nextInt(1000001) - 500000,
        );
        amounts[0] -= amounts.fold<int>(0, (a, b) => a + b);

        final balances = [
          for (var i = 0; i < count; i++) balance('M$i', amounts[i]),
        ];

        final transfers = DebtSimplifier.simplify(balances);
        final moved = transfers.fold<int>(0, (sum, t) => sum + t.amount);
        final credit = balances
            .where((b) => b.balance > 0)
            .fold<int>(0, (sum, b) => sum + b.balance);

        expect(moved, credit, reason: 'Lần $iteration');
      }
    });
  });

  group('MemberBalance', () {
    test('số dư gộp đủ bốn nguồn tiền', () {
      const result = MemberBalance(
        memberId: 'An',
        memberName: 'An',
        avatarColor: 0,
        advanced: 900000,
        owed: 300000,
        sent: 50000,
        received: 20000,
      );

      // 900.000 đã ứng − 300.000 phải chịu + 50.000 đã chuyển − 20.000 đã nhận
      expect(result.balance, 630000);
      expect(result.isCreditor, isTrue);
      expect(result.isDebtor, isFalse);
      expect(result.isClear, isFalse);
    });
  });
}

/// Khẳng định rằng sau khi thực hiện [transfers], mọi số dư về 0.
void _expectSettles(
  List<MemberBalance> balances,
  List<SettlementTransfer> transfers, {
  int? iteration,
}) {
  final after = {for (final b in balances) b.memberId: b.balance};

  for (final transfer in transfers) {
    expect(
      transfer.amount,
      greaterThan(0),
      reason: 'Không được gợi ý chuyển 0 đồng',
    );
    after[transfer.fromMemberId] =
        (after[transfer.fromMemberId] ?? 0) + transfer.amount;
    after[transfer.toMemberId] =
        (after[transfer.toMemberId] ?? 0) - transfer.amount;
  }

  for (final entry in after.entries) {
    expect(
      entry.value,
      0,
      reason: iteration == null
          ? '${entry.key} còn lệch ${entry.value}'
          : 'Lần $iteration: ${entry.key} còn lệch ${entry.value}',
    );
  }
}
