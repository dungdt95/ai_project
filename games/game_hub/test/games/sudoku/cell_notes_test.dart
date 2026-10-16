import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/sudoku/domain/cell.dart';

void main() {
  group('Cell', () {
    test('default cell is empty', () {
      const c = Cell();
      expect(c.value, isNull);
      expect(c.notes, isEmpty);
      expect(c.isGiven, isFalse);
      expect(c.isEmpty, isTrue);
    });

    test('copyWith value', () {
      const c = Cell();
      final c2 = c.copyWith(value: 5);
      expect(c2.value, 5);
      expect(c2.notes, isEmpty);
      expect(c2.isGiven, isFalse);
    });

    test('clearValue works', () {
      final c = Cell(value: 3);
      final c2 = c.copyWith(clearValue: true);
      expect(c2.value, isNull);
    });

    test('notes add and remove', () {
      const c = Cell();
      final c2 = c.copyWith(notes: {1, 3, 5});
      expect(c2.notes, containsAll([1, 3, 5]));

      final c3 = c2.copyWith(notes: c2.notes.difference({3}));
      expect(c3.notes, containsAll([1, 5]));
      expect(c3.notes, isNot(contains(3)));
    });

    test('isGiven cannot be changed by copyWith without explicit param', () {
      final given = Cell(value: 7, isGiven: true);
      final c2 = given.copyWith(value: 8);
      expect(c2.isGiven, isTrue);
    });

    test('equality', () {
      final a = Cell(value: 3, notes: {1, 2});
      final b = Cell(value: 3, notes: {2, 1});
      expect(a, equals(b));
    });

    test('inequality when value differs', () {
      final a = Cell(value: 3);
      final b = Cell(value: 4);
      expect(a, isNot(equals(b)));
    });

    test('isEmpty only when both value and notes are absent', () {
      expect(const Cell().isEmpty, isTrue);
      expect(Cell(value: 1).isEmpty, isFalse);
      expect(Cell(notes: {1}).isEmpty, isFalse);
    });
  });
}
