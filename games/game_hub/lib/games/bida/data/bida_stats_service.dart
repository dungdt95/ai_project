import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/variant.dart';

class BidaGameRecord {
  const BidaGameRecord({
    required this.variant,
    required this.mode,
    required this.playerWon,
    required this.shots,
    required this.fouls,
    required this.playedAt,
    this.vsAiLevel,
  });

  final BidaVariant variant;
  final BidaMode mode;
  final bool playerWon;
  final int shots;
  final int fouls;
  final DateTime playedAt;
  final AiLevel? vsAiLevel;

  Map<String, dynamic> toJson() => {
        'variant': variant.index,
        'mode': mode.index,
        'playerWon': playerWon,
        'shots': shots,
        'fouls': fouls,
        'playedAt': playedAt.millisecondsSinceEpoch,
        'vsAiLevel': vsAiLevel?.index,
      };

  factory BidaGameRecord.fromJson(Map<dynamic, dynamic> j) => BidaGameRecord(
        variant: BidaVariant.values[j['variant'] as int],
        mode: BidaMode.values[j['mode'] as int],
        playerWon: j['playerWon'] as bool,
        shots: j['shots'] as int,
        fouls: j['fouls'] as int,
        playedAt: DateTime.fromMillisecondsSinceEpoch(j['playedAt'] as int),
        vsAiLevel: j['vsAiLevel'] != null ? AiLevel.values[j['vsAiLevel'] as int] : null,
      );
}

class BidaVariantStats {
  const BidaVariantStats({
    required this.variant,
    required this.games,
    required this.wins,
    required this.losses,
    required this.bestShotWin,
  });

  final BidaVariant variant;
  final int games;
  final int wins;
  final int losses;
  final int bestShotWin; // 0 = never won

  double get winRate => games == 0 ? 0 : wins / games;
}

class BidaTotalStats {
  const BidaTotalStats({
    required this.totalGames,
    required this.totalWins,
    required this.totalShots,
    required this.totalFouls,
    required this.beatHardAi,
    required this.noFoulWin,
  });

  final int totalGames;
  final int totalWins;
  final int totalShots;
  final int totalFouls;
  final bool beatHardAi;
  final bool noFoulWin;
}

class DailyResult {
  const DailyResult({required this.shots, required this.fouls, required this.date});
  final int shots;
  final int fouls;
  final String date; // yyyy-MM-dd
}

class BidaStatsService {
  BidaStatsService._();
  static final instance = BidaStatsService._();

  static const _boxName = 'bida_stats';
  late Box _box;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  Future<void> saveGame(BidaGameRecord record) async {
    final key = 'game_${record.playedAt.millisecondsSinceEpoch}';
    await _box.put(key, jsonEncode(record.toJson()));
  }

  List<BidaGameRecord> _allRecords() {
    return _box.keys
        .where((k) => (k as String).startsWith('game_'))
        .map((k) => BidaGameRecord.fromJson(
            jsonDecode(_box.get(k) as String) as Map))
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  BidaVariantStats statsFor(BidaVariant variant) {
    final records = _allRecords()
        .where((r) => r.variant == variant && r.mode != BidaMode.practice)
        .toList();
    int wins = 0, losses = 0, bestShots = 0;
    for (final r in records) {
      if (r.playerWon) {
        wins++;
        if (bestShots == 0 || r.shots < bestShots) bestShots = r.shots;
      } else {
        losses++;
      }
    }
    return BidaVariantStats(
      variant: variant,
      games: records.length,
      wins: wins,
      losses: losses,
      bestShotWin: bestShots,
    );
  }

  BidaTotalStats totalStats() {
    final records = _allRecords().where((r) => r.mode != BidaMode.practice).toList();
    int wins = 0, shots = 0, fouls = 0;
    bool beatHard = false, noFoul = false;
    for (final r in records) {
      if (r.playerWon) {
        wins++;
        if (r.vsAiLevel == AiLevel.hard) beatHard = true;
        if (r.fouls == 0) noFoul = true;
      }
      shots += r.shots;
      fouls += r.fouls;
    }
    return BidaTotalStats(
      totalGames: records.length,
      totalWins: wins,
      totalShots: shots,
      totalFouls: fouls,
      beatHardAi: beatHard,
      noFoulWin: noFoul,
    );
  }

  // ── Achievements ────────────────────────────────────────────────────────────

  Set<String> get unlockedAchievements {
    final raw = _box.get('achievements') as String? ?? '[]';
    return Set<String>.from(jsonDecode(raw) as List);
  }

  Future<List<String>> checkAndUnlockAchievements() async {
    final records = _allRecords().where((r) => r.mode != BidaMode.practice).toList();
    final already = unlockedAchievements;
    final newlyUnlocked = <String>[];

    void tryUnlock(String id) {
      if (!already.contains(id)) {
        already.add(id);
        newlyUnlocked.add(id);
      }
    }

    final wins = records.where((r) => r.playerWon).toList();
    final totalWins = wins.length;

    if (totalWins >= 1)  tryUnlock('first_win');
    if (totalWins >= 10) tryUnlock('wins_10');
    if (totalWins >= 50) tryUnlock('wins_50');

    if (wins.any((r) => r.vsAiLevel == AiLevel.hard)) tryUnlock('beat_hard_ai');
    if (wins.any((r) => r.fouls == 0))               tryUnlock('no_foul_win');

    // Quick win: ≤12 shots in 9-ball
    if (wins.any((r) => r.variant == BidaVariant.nineBall && r.shots <= 12)) {
      tryUnlock('quick_win_9ball');
    }

    // Win with all 3 pocket variants
    final wonVariants = wins.map((r) => r.variant).toSet();
    if ({BidaVariant.eightBall, BidaVariant.nineBall, BidaVariant.vnBall}
        .every(wonVariants.contains)) {
      tryUnlock('all_pocket_variants');
    }

    if (newlyUnlocked.isNotEmpty) {
      await _box.put('achievements', jsonEncode(already.toList()));
    }
    return newlyUnlocked;
  }

  // ── Daily challenge ─────────────────────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return 'daily_${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  bool get dailyCompleted => _box.containsKey(_todayKey());

  DailyResult? get todayResult {
    final raw = _box.get(_todayKey()) as String?;
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map;
    return DailyResult(
      shots: m['shots'] as int,
      fouls: m['fouls'] as int,
      date: _todayKey().substring(6),
    );
  }

  Future<void> saveDailyResult(int shots, int fouls) async {
    final key = _todayKey();
    if (_box.containsKey(key)) return; // only save first attempt
    await _box.put(key, jsonEncode({'shots': shots, 'fouls': fouls}));
  }
}
