import 'package:hive_flutter/hive_flutter.dart';
import '../domain/variant.dart';
import 'sudoku_history_service.dart';

enum SudokuAchievement {
  firstWin('first_win', 'Tân binh', 'Hoàn thành puzzle đầu tiên'),
  easyMaster('easy_master', 'Khởi đầu thuận lợi', 'Hoàn thành 10 Easy'),
  expert5('expert_5', 'Cao thủ Expert', 'Hoàn thành 5 Expert'),
  noMistakes('no_mistakes', 'Tinh mắt', 'Hoàn thành 1 puzzle không sai'),
  noHints('no_hints', 'Tự lực', 'Hoàn thành Hard+ không dùng hint'),
  streak7('streak_7', 'Tuần lễ vàng', 'Daily streak 7 ngày'),
  streak30('streak_30', 'Bền bỉ', 'Daily streak 30 ngày'),
  speedDemon('speed_demon', 'Tốc độ', 'Hoàn thành Easy < 3 phút'),
  killerFirst('killer_first', 'Sát thủ', 'Hoàn thành Killer đầu tiên'),
  xFirst('x_first', 'Chéo cánh', 'Hoàn thành X-Sudoku đầu tiên'),
  allVariants('all_variants', 'Đa di năng', 'Hoàn thành cả 3 variant mọi difficulty');

  const SudokuAchievement(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

class AchievementService {
  AchievementService._();
  static final AchievementService instance = AchievementService._();

  static const _boxName = 'sudoku_achievements';
  late Box _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  bool isUnlocked(SudokuAchievement a) =>
      _box.get(a.id, defaultValue: false) as bool;

  Set<SudokuAchievement> get unlocked =>
      SudokuAchievement.values.where(isUnlocked).toSet();

  Future<void> unlock(SudokuAchievement a) async {
    await _box.put(a.id, true);
  }

  /// Checks all achievements after a game record is saved.
  /// Returns newly unlocked achievements.
  Future<List<SudokuAchievement>> checkAfterGame({
    required SudokuGameRecord record,
    required SudokuStats stats,
    required int currentStreak,
  }) async {
    final newly = <SudokuAchievement>[];

    Future<void> tryUnlock(SudokuAchievement a, bool condition) async {
      if (!isUnlocked(a) && condition) {
        await unlock(a);
        newly.add(a);
      }
    }

    final total = stats.byVariantDifficulty.values.fold(0, (s, v) => s + v);
    await tryUnlock(SudokuAchievement.firstWin, total >= 1);

    await tryUnlock(
      SudokuAchievement.easyMaster,
      stats.countFor(SudokuVariant.classic, SudokuDifficulty.easy) >= 10,
    );

    final expertTotal = SudokuVariant.values.fold(
      0,
      (s, v) => s + stats.countFor(v, SudokuDifficulty.expert),
    );
    await tryUnlock(SudokuAchievement.expert5, expertTotal >= 5);

    await tryUnlock(
        SudokuAchievement.noMistakes, record.mistakeCount == 0);

    await tryUnlock(
      SudokuAchievement.noHints,
      record.hintsUsed == 0 &&
          (record.difficulty == SudokuDifficulty.hard ||
              record.difficulty == SudokuDifficulty.expert),
    );

    await tryUnlock(SudokuAchievement.streak7, currentStreak >= 7);
    await tryUnlock(SudokuAchievement.streak30, currentStreak >= 30);

    await tryUnlock(
      SudokuAchievement.speedDemon,
      record.difficulty == SudokuDifficulty.easy &&
          record.duration.inSeconds < 180,
    );

    await tryUnlock(
      SudokuAchievement.killerFirst,
      record.variant == SudokuVariant.killer,
    );

    await tryUnlock(
      SudokuAchievement.xFirst,
      record.variant == SudokuVariant.xSudoku,
    );

    bool allDone = true;
    for (final v in SudokuVariant.values) {
      for (final d in SudokuDifficulty.values) {
        if (stats.countFor(v, d) == 0) {
          allDone = false;
          break;
        }
      }
    }
    await tryUnlock(SudokuAchievement.allVariants, allDone);

    return newly;
  }
}
