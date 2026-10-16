import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/storage/settings_service.dart';
import 'core/audio/audio_service.dart';
import 'games/caro/caro_game.dart';
import 'games/caro/data/caro_history_service.dart';
import 'games/bida/bida_game.dart';
import 'games/bida/data/bida_stats_service.dart';
import 'games/sudoku/sudoku_game.dart';
import 'core/game_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  final settings = SettingsService.instance;
  await settings.init();

  final history = CaroHistoryService.instance;
  await history.init();

  await BidaStatsService.instance.init();

  AudioService.instance.enabled = settings.soundEnabled;

  await SudokuGame().onAppStart();

  _registerGames();

  runApp(const ProviderScope(child: GameHubApp()));
}

void _registerGames() {
  GameRegistry.instance.register(CaroGame());
  GameRegistry.instance.register(BidaGame());
  GameRegistry.instance.register(SudokuGame());
}
