import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/move.dart';
import '../domain/variant.dart';

class SudokuGameRecord {
  SudokuGameRecord({
    required this.id,
    required this.variant,
    required this.difficulty,
    required this.duration,
    required this.completedAt,
    required this.moves,
    required this.mistakeCount,
    required this.hintsUsed,
    this.isDaily = false,
  });

  final String id;
  final SudokuVariant variant;
  final SudokuDifficulty difficulty;
  final Duration duration;
  final DateTime completedAt;
  final List<SudokuMove> moves;
  final int mistakeCount;
  final int hintsUsed;
  final bool isDaily;

  Map<String, dynamic> toJson() => {
        'id': id,
        'variant': variant.index,
        'difficulty': difficulty.index,
        'duration': duration.inSeconds,
        'completedAt': completedAt.millisecondsSinceEpoch,
        'moves': moves.map((m) => m.toJson()).toList(),
        'mistakeCount': mistakeCount,
        'hintsUsed': hintsUsed,
        'isDaily': isDaily,
      };

  factory SudokuGameRecord.fromJson(Map j) => SudokuGameRecord(
        id: j['id'] as String,
        variant: SudokuVariant.values[j['variant'] as int],
        difficulty: SudokuDifficulty.values[j['difficulty'] as int],
        duration: Duration(seconds: j['duration'] as int),
        completedAt:
            DateTime.fromMillisecondsSinceEpoch(j['completedAt'] as int),
        moves: (j['moves'] as List)
            .map((e) => SudokuMove.fromJson(e as Map))
            .toList(),
        mistakeCount: j['mistakeCount'] as int? ?? 0,
        hintsUsed: j['hintsUsed'] as int? ?? 0,
        isDaily: j['isDaily'] as bool? ?? false,
      );
}

class SudokuStats {
  const SudokuStats({
    required this.byVariantDifficulty,
    required this.bestTimes,
    required this.noMistake,
    required this.noHint,
  });

  // key: "${variant.index}_${difficulty.index}"
  final Map<String, int> byVariantDifficulty;
  final Map<String, Duration?> bestTimes;
  final int noMistake;
  final int noHint;

  int countFor(SudokuVariant v, SudokuDifficulty d) =>
      byVariantDifficulty['${v.index}_${d.index}'] ?? 0;

  Duration? bestTimeFor(SudokuVariant v, SudokuDifficulty d) =>
      bestTimes['${v.index}_${d.index}'];
}

class SudokuHistoryService {
  SudokuHistoryService._();
  static final SudokuHistoryService instance = SudokuHistoryService._();

  static const _boxName = 'sudoku_history';
  late Box _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  Future<void> save(SudokuGameRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  List<SudokuGameRecord> getAll() {
    return _box.values
        .map((v) =>
            SudokuGameRecord.fromJson(jsonDecode(v as String) as Map))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  SudokuStats computeStats() {
    final records = getAll();
    final counts = <String, int>{};
    final best = <String, Duration?>{};
    int noMistake = 0, noHint = 0;

    for (final r in records) {
      final key = '${r.variant.index}_${r.difficulty.index}';
      counts[key] = (counts[key] ?? 0) + 1;
      if (best[key] == null || r.duration < best[key]!) {
        best[key] = r.duration;
      }
      if (r.mistakeCount == 0) noMistake++;
      if (r.hintsUsed == 0 &&
          (r.difficulty == SudokuDifficulty.hard ||
              r.difficulty == SudokuDifficulty.expert)) noHint++;
    }
    return SudokuStats(
      byVariantDifficulty: counts,
      bestTimes: best,
      noMistake: noMistake,
      noHint: noHint,
    );
  }

  Future<void> clear() => _box.clear();
}
