import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/solver/daily_seed.dart';

void main() {
  group('dailySeed', () {
    test('same date produces same seed', () {
      final d = DateTime(2025, 6, 15);
      expect(dailySeed(d), equals(dailySeed(d)));
    });

    test('different dates produce different seeds', () {
      final d1 = DateTime(2025, 6, 15);
      final d2 = DateTime(2025, 6, 16);
      expect(dailySeed(d1), isNot(equals(dailySeed(d2))));
    });

    test('seed is non-negative', () {
      final d = DateTime(2025, 1, 1);
      expect(dailySeed(d), greaterThanOrEqualTo(0));
    });

    test('time-of-day does not affect seed', () {
      final morning = DateTime(2025, 6, 15, 8, 0, 0);
      final evening = DateTime(2025, 6, 15, 22, 30, 0);
      expect(dailySeed(morning), equals(dailySeed(evening)));
    });
  });
}
