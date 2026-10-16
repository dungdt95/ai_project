import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/caro/domain/board.dart';
import 'package:game_hub/games/caro/domain/move.dart';
import 'package:game_hub/games/caro/ai/easy_ai.dart';
import 'package:game_hub/games/caro/ai/medium_ai.dart';
import 'package:game_hub/games/caro/ai/hard_ai.dart';

Board _place(Board board, int r, int c, Player p) {
  return board.applyMove(
    Move(position: Position(r, c), player: p, timestamp: DateTime.now()),
  );
}

void main() {
  group('EasyAi', () {
    test('blocks opponent immediate win', () async {
      // X has 4-in-a-row at (7,5..8), AI (O) should block (7,9) or (7,4).
      var board = Board();
      board = _place(board, 7, 5, Player.x);
      board = _place(board, 7, 6, Player.x);
      board = _place(board, 7, 7, Player.x);
      board = _place(board, 7, 8, Player.x);

      final ai = EasyAi();
      final move = await ai.chooseMove(board, Player.o, const Duration(seconds: 1));
      expect(
        move.position == const Position(7, 9) || move.position == const Position(7, 4),
        isTrue,
        reason: 'Easy AI should block the 4-in-a-row threat',
      );
    });
  });

  group('MediumAi', () {
    test('blocks opponent immediate win', () async {
      var board = Board();
      board = _place(board, 7, 5, Player.x);
      board = _place(board, 7, 6, Player.x);
      board = _place(board, 7, 7, Player.x);
      board = _place(board, 7, 8, Player.x);

      final ai = MediumAi();
      final move = await ai.chooseMove(board, Player.o, const Duration(seconds: 1));
      expect(
        move.position == const Position(7, 9) || move.position == const Position(7, 4),
        isTrue,
        reason: 'Medium AI should block the 4-in-a-row threat',
      );
    });

    test('takes immediate win if available', () async {
      var board = Board();
      board = _place(board, 7, 5, Player.o);
      board = _place(board, 7, 6, Player.o);
      board = _place(board, 7, 7, Player.o);
      board = _place(board, 7, 8, Player.o);

      final ai = MediumAi();
      final move = await ai.chooseMove(board, Player.o, const Duration(seconds: 1));
      expect(
        move.position == const Position(7, 9) || move.position == const Position(7, 4),
        isTrue,
        reason: 'Medium AI should complete 5 to win',
      );
    });
  });

  group('HardAi', () {
    test('wins immediately when possible', () async {
      var board = Board();
      board = _place(board, 7, 5, Player.x);
      board = _place(board, 7, 6, Player.x);
      board = _place(board, 7, 7, Player.x);
      board = _place(board, 7, 8, Player.x);

      final ai = HardAi();
      final move = await ai.chooseMove(board, Player.x, const Duration(seconds: 3));
      expect(
        move.position == const Position(7, 9) || move.position == const Position(7, 4),
        isTrue,
        reason: 'Hard AI should take the winning move',
      );
    });

    test('blocks opponent immediate win', () async {
      var board = Board();
      board = _place(board, 7, 5, Player.o);
      board = _place(board, 7, 6, Player.o);
      board = _place(board, 7, 7, Player.o);
      board = _place(board, 7, 8, Player.o);

      final ai = HardAi();
      final move = await ai.chooseMove(board, Player.x, const Duration(seconds: 3));
      expect(
        move.position == const Position(7, 9) || move.position == const Position(7, 4),
        isTrue,
        reason: 'Hard AI should block opponent\'s win',
      );
    });
  });
}
