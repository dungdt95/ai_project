import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/move.dart';

enum GameMode { vsAiEasy, vsAiMedium, vsAiHard, vsAiSuper, vsHumanLan, vsHumanLocal }
enum GameResult { win, lose, draw, resign }

extension GameModeLabel on GameMode {
  String get label => switch (this) {
        GameMode.vsAiEasy => 'AI Easy',
        GameMode.vsAiMedium => 'AI Medium',
        GameMode.vsAiHard => 'AI Hard',
        GameMode.vsAiSuper => 'AI Super',
        GameMode.vsHumanLan => 'LAN',
        GameMode.vsHumanLocal => 'Local',
      };
}

class GameRecord {
  GameRecord({
    required this.id,
    required this.mode,
    required this.result,
    required this.moves,
    required this.startedAt,
    required this.duration,
    this.opponentName,
    this.playerSide = Player.x,
  });

  final String id;
  final GameMode mode;
  final GameResult result;
  final List<Move> moves;
  final DateTime startedAt;
  final Duration duration;
  final String? opponentName;
  final Player playerSide;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.index,
        'result': result.index,
        'moves': moves.map((m) => m.toJson()).toList(),
        'startedAt': startedAt.millisecondsSinceEpoch,
        'duration': duration.inSeconds,
        'opponentName': opponentName,
        'playerSide': playerSide.index,
      };

  factory GameRecord.fromJson(Map<dynamic, dynamic> j) => GameRecord(
        id: j['id'] as String,
        mode: GameMode.values[j['mode'] as int],
        result: GameResult.values[j['result'] as int],
        moves: (j['moves'] as List)
            .map((m) => Move.fromJson(m as Map))
            .toList(),
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(j['startedAt'] as int),
        duration: Duration(seconds: j['duration'] as int),
        opponentName: j['opponentName'] as String?,
        playerSide: Player.values[j['playerSide'] as int? ?? 0],
      );
}

class CaroHistoryService {
  CaroHistoryService._();
  static final CaroHistoryService instance = CaroHistoryService._();

  static const _boxName = 'caro_history';

  late Box _box;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  Future<void> save(GameRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  List<GameRecord> getAll() {
    return _box.values
        .map((v) => GameRecord.fromJson(jsonDecode(v as String) as Map))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();

  CaroStats stats() {
    final records = getAll();
    int wins = 0, losses = 0, draws = 0;
    int streak = 0;
    bool streakPositive = true;

    for (int i = 0; i < records.length; i++) {
      final r = records[i].result;
      if (i == 0) {
        streakPositive = r == GameResult.win;
      }
      if (r == GameResult.win) {
        wins++;
        if (streakPositive) streak++;
      } else if (r == GameResult.lose || r == GameResult.resign) {
        losses++;
        if (!streakPositive) streak++;
      } else {
        draws++;
        streak = 0;
      }
    }
    return CaroStats(
      total: records.length,
      wins: wins,
      losses: losses,
      draws: draws,
      streak: streak,
      streakPositive: streakPositive,
    );
  }
}

class CaroStats {
  const CaroStats({
    required this.total,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.streak,
    required this.streakPositive,
  });

  final int total;
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final bool streakPositive;

  double get winRate => total == 0 ? 0 : wins / total;
}
