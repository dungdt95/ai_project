import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_engine.dart';
import '../ai/easy_ai.dart';
import '../ai/medium_ai.dart';
import '../ai/hard_ai.dart';
import '../ai/super_ai.dart';
import '../data/caro_history_service.dart';
import '../domain/board.dart';
import '../domain/move.dart';
import '../domain/rules.dart';
import '../network/lan_host.dart';
import '../network/lan_client.dart';
import '../network/protocol.dart';
import '../../../core/audio/audio_service.dart';

class CaroGameState {
  const CaroGameState({
    required this.board,
    required this.mode,
    required this.playerXName,
    required this.playerOName,
    required this.humanSide,
    this.difficulty,
    this.isThinking = false,
    this.hintPosition,
    this.undoUsed = 0,
    this.hintUsed = 0,
    this.startedAt,
    this.gameRecordId,
    this.lanHost,
    this.lanClient,
    this.lanConnected = false,
  });

  final Board board;
  final GameMode mode;
  final String playerXName;
  final String playerOName;
  final Player humanSide;
  final AiDifficulty? difficulty;
  final bool isThinking;
  final Position? hintPosition;
  final int undoUsed;
  final int hintUsed;
  final DateTime? startedAt;
  final String? gameRecordId;
  final LanHost? lanHost;
  final LanClient? lanClient;
  final bool lanConnected;

  static const maxUndos = 3;
  static const maxHints = 3;

  bool get canUndo =>
      undoUsed < maxUndos &&
      board.history.length >= 2 &&
      !board.isOver &&
      mode != GameMode.vsHumanLan;

  bool get canHint =>
      hintUsed < maxHints && !board.isOver && mode != GameMode.vsHumanLan;

  bool get isMyTurn =>
      mode == GameMode.vsHumanLocal ||
      mode == GameMode.vsHumanLan
          ? true
          : board.currentTurn == humanSide;

  CaroGameState copyWith({
    Board? board,
    GameMode? mode,
    String? playerXName,
    String? playerOName,
    Player? humanSide,
    AiDifficulty? difficulty,
    bool? isThinking,
    Position? hintPosition,
    bool clearHint = false,
    int? undoUsed,
    int? hintUsed,
    DateTime? startedAt,
    String? gameRecordId,
    LanHost? lanHost,
    LanClient? lanClient,
    bool? lanConnected,
  }) =>
      CaroGameState(
        board: board ?? this.board,
        mode: mode ?? this.mode,
        playerXName: playerXName ?? this.playerXName,
        playerOName: playerOName ?? this.playerOName,
        humanSide: humanSide ?? this.humanSide,
        difficulty: difficulty ?? this.difficulty,
        isThinking: isThinking ?? this.isThinking,
        hintPosition: clearHint ? null : (hintPosition ?? this.hintPosition),
        undoUsed: undoUsed ?? this.undoUsed,
        hintUsed: hintUsed ?? this.hintUsed,
        startedAt: startedAt ?? this.startedAt,
        gameRecordId: gameRecordId ?? this.gameRecordId,
        lanHost: lanHost ?? this.lanHost,
        lanClient: lanClient ?? this.lanClient,
        lanConnected: lanConnected ?? this.lanConnected,
      );
}

enum AiDifficulty { easy, medium, hard, superHard }

final caroGameProvider =
    StateNotifierProvider<CaroGameNotifier, CaroGameState>(
  (ref) => CaroGameNotifier(),
);

class CaroGameNotifier extends StateNotifier<CaroGameState> {
  CaroGameNotifier()
      : super(CaroGameState(
          board: Board(),
          mode: GameMode.vsAiMedium,
          playerXName: 'Player',
          playerOName: 'AI',
          humanSide: Player.x,
        ));

  final _historyService = CaroHistoryService.instance;
  final _audio = AudioService.instance;

  Future<void> initHistory() async {
    await _historyService.init();
  }

  void startVsAi({
    required String playerName,
    required AiDifficulty difficulty,
    required Player humanSide,
  }) {
    final mode = switch (difficulty) {
      AiDifficulty.easy => GameMode.vsAiEasy,
      AiDifficulty.medium => GameMode.vsAiMedium,
      AiDifficulty.hard => GameMode.vsAiHard,
      AiDifficulty.superHard => GameMode.vsAiSuper,
    };
    state = CaroGameState(
      board: Board(),
      mode: mode,
      playerXName: humanSide == Player.x ? playerName : 'AI',
      playerOName: humanSide == Player.o ? playerName : 'AI',
      humanSide: humanSide,
      difficulty: difficulty,
      startedAt: DateTime.now(),
      gameRecordId: const Uuid().v4(),
    );

    if (humanSide == Player.o) {
      // AI goes first as X
      _triggerAiMove();
    }
  }

  void startLocal({
    required String playerXName,
    required String playerOName,
  }) {
    state = CaroGameState(
      board: Board(),
      mode: GameMode.vsHumanLocal,
      playerXName: playerXName,
      playerOName: playerOName,
      humanSide: Player.x,
      startedAt: DateTime.now(),
      gameRecordId: const Uuid().v4(),
    );
  }

  void startLanHost({required String hostName, required LanHost host}) {
    state = CaroGameState(
      board: Board(),
      mode: GameMode.vsHumanLan,
      playerXName: hostName,
      playerOName: '...',
      humanSide: Player.x,
      lanHost: host,
      startedAt: DateTime.now(),
      gameRecordId: const Uuid().v4(),
    );
    host.onPacket.listen(_handleLanPacket);
    host.onError.listen((_) => state = state.copyWith(lanConnected: false));
  }

  void startLanClient({required String playerName, required LanClient client}) {
    state = CaroGameState(
      board: Board(),
      mode: GameMode.vsHumanLan,
      playerXName: client.hostName ?? 'Host',
      playerOName: playerName,
      humanSide: Player.o,
      lanClient: client,
      lanConnected: true,
      startedAt: DateTime.now(),
      gameRecordId: const Uuid().v4(),
    );
    client.onPacket.listen(_handleLanPacket);
    client.onError.listen((_) => state = state.copyWith(lanConnected: false));
  }

  Future<void> placeStone(Position pos) async {
    if (!CaroRules.isLegalMove(state.board, pos)) return;
    if (state.isThinking) return;
    if (state.mode != GameMode.vsHumanLocal &&
        state.mode != GameMode.vsHumanLan &&
        state.board.currentTurn != state.humanSide) return;

    final move = Move(
      position: pos,
      player: state.board.currentTurn,
      timestamp: DateTime.now(),
    );
    _applyMove(move);

    // Send move over LAN.
    final moveNo = state.board.history.length;
    state.lanHost?.sendMove(row: pos.row, col: pos.col, moveNo: moveNo);
    state.lanClient?.sendMove(row: pos.row, col: pos.col, moveNo: moveNo);

    if (!state.board.isOver && state.mode != GameMode.vsHumanLocal &&
        state.mode != GameMode.vsHumanLan) {
      _triggerAiMove();
    }
  }

  void _applyMove(Move move) {
    var newBoard = state.board.applyMove(move);
    final gameStatus = CaroRules.evaluate(newBoard, move);
    if (gameStatus != GameStatus.playing) {
      final line = CaroRules.findWinningLine(newBoard, move.player);
      newBoard = newBoard.withStatus(gameStatus, line: line);
    }

    state = state.copyWith(board: newBoard, isThinking: false, clearHint: true);

    if (newBoard.isOver) {
      _onGameOver();
    } else {
      _audio.playMove();
      HapticFeedback.lightImpact();
    }
  }

  void _onGameOver() {
    final board = state.board;
    GameResult result;
    if (board.status == GameStatus.draw) {
      result = GameResult.draw;
      _audio.playDraw();
    } else {
      final winnerIsHuman = (board.status == GameStatus.xWon &&
              state.humanSide == Player.x) ||
          (board.status == GameStatus.oWon && state.humanSide == Player.o);
      result = winnerIsHuman ? GameResult.win : GameResult.lose;
      if (result == GameResult.win) {
        _audio.playWin();
        HapticFeedback.heavyImpact();
      } else {
        _audio.playLose();
      }
    }
    _saveRecord(result);
  }

  void _saveRecord(GameResult result) {
    if (state.gameRecordId == null) return;
    final record = GameRecord(
      id: state.gameRecordId!,
      mode: state.mode,
      result: result,
      moves: List.from(state.board.history),
      startedAt: state.startedAt ?? DateTime.now(),
      duration: DateTime.now().difference(state.startedAt ?? DateTime.now()),
      opponentName: state.humanSide == Player.x
          ? state.playerOName
          : state.playerXName,
      playerSide: state.humanSide,
    );
    _historyService.save(record);
  }

  Future<void> _triggerAiMove() async {
    if (state.board.isOver) return;
    state = state.copyWith(isThinking: true);
    final ai = _buildAi(state.difficulty ?? AiDifficulty.medium);
    final timeLimit = state.difficulty == AiDifficulty.superHard
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 500);
    try {
      final move = await ai.chooseMove(
        state.board,
        state.board.currentTurn,
        timeLimit,
      );
      if (!mounted) return;
      _applyMove(move);
    } catch (_) {
      if (mounted) state = state.copyWith(isThinking: false);
    }
  }

  AiEngine _buildAi(AiDifficulty d) => switch (d) {
        AiDifficulty.easy => EasyAi(),
        AiDifficulty.medium => MediumAi(),
        AiDifficulty.hard => HardAi(),
        AiDifficulty.superHard => SuperAi(),
      };

  Future<void> requestHint() async {
    if (!state.canHint) return;
    state = state.copyWith(isThinking: true);
    final ai = HardAi();
    try {
      final move = await ai.chooseMove(
        state.board,
        state.board.currentTurn,
        const Duration(milliseconds: 500),
      );
      if (mounted) {
        state = state.copyWith(
          isThinking: false,
          hintPosition: move.position,
          hintUsed: state.hintUsed + 1,
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isThinking: false);
    }
  }

  void undo() {
    if (!state.canUndo) return;
    // Undo both human move and AI move.
    final newBoard = state.board.undoMoves(2);
    state = state.copyWith(
      board: newBoard,
      undoUsed: state.undoUsed + 1,
      clearHint: true,
    );
  }

  void resign() {
    if (state.board.isOver) return;
    final loser = state.mode == GameMode.vsHumanLocal
        ? state.board.currentTurn
        : state.humanSide;
    final winnerStatus =
        loser == Player.x ? GameStatus.oWon : GameStatus.xWon;
    state = state.copyWith(
      board: state.board.withStatus(winnerStatus),
      clearHint: true,
    );
    _saveRecord(GameResult.resign);
    _audio.playLose();
  }

  void newGame() {
    final s = state;
    state = CaroGameState(
      board: Board(),
      mode: s.mode,
      playerXName: s.playerXName,
      playerOName: s.playerOName,
      humanSide: s.humanSide,
      difficulty: s.difficulty,
      lanHost: s.lanHost,
      lanClient: s.lanClient,
      lanConnected: s.lanConnected,
      startedAt: DateTime.now(),
      gameRecordId: const Uuid().v4(),
    );
    if (s.mode != GameMode.vsHumanLocal &&
        s.mode != GameMode.vsHumanLan &&
        s.humanSide == Player.o) {
      _triggerAiMove();
    }
  }

  void _handleLanPacket(Packet p) {
    switch (p.type) {
      case PacketType.move:
        final row = p.payload['row'] as int;
        final col = p.payload['col'] as int;
        final move = Move(
          position: Position(row, col),
          player: state.board.currentTurn,
          timestamp: DateTime.now(),
        );
        _applyMove(move);
      case PacketType.end:
        // Opponent resigned or game over confirmed.
        break;
      case PacketType.rematchRequest:
        // UI should show dialog — just signal via state change.
        break;
      case PacketType.rematchAccept:
        newGame();
      default:
        break;
    }
  }

  List<GameRecord> getHistory() => _historyService.getAll();
  CaroStats getStats() => _historyService.stats();

  @override
  void dispose() {
    state.lanHost?.dispose();
    state.lanClient?.dispose();
    super.dispose();
  }
}

// Helper to pick random side.
Player randomSide() => Random().nextBool() ? Player.x : Player.o;
