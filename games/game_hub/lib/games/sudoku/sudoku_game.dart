import 'package:flutter/material.dart';
import '../../core/game_module.dart';
import 'data/achievement_service.dart';
import 'data/daily_streak_service.dart';
import 'data/sudoku_history_service.dart';
import 'data/sudoku_save_service.dart';
import 'presentation/sudoku_menu_screen.dart';

/// GameModule implementation for Sudoku.
class SudokuGame extends GameModule {
  @override
  String get id => 'sudoku';

  @override
  String get nameKey => 'gameSudokuName';

  @override
  String get descriptionKey => 'gameSudokuDescription';

  @override
  Widget buildIcon(BuildContext context) => const Icon(
        Icons.grid_4x4,
        size: 48,
        color: Color(0xFF7B1FA2),
      );

  @override
  Widget buildEntryScreen(BuildContext context) => const SudokuMenuScreen();

  @override
  Future<void> onAppStart() async {
    await SudokuHistoryService.instance.init();
    await SudokuSaveService.instance.init();
    await DailyStreakService.instance.init();
    await AchievementService.instance.init();
  }
}
