import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/settings_service.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'games/caro/presentation/caro_menu_screen.dart';
import 'games/caro/presentation/caro_game_screen.dart';
import 'games/caro/presentation/caro_lan_lobby_screen.dart';
import 'games/caro/presentation/caro_history_screen.dart';
import 'games/caro/presentation/caro_stats_screen.dart';
import 'games/caro/data/caro_history_service.dart';
import 'games/bida/presentation/bida_menu_screen.dart';
import 'games/bida/presentation/bida_game_screen.dart';
import 'games/bida/presentation/bida_stats_screen.dart';
import 'games/bida/domain/variant.dart' show BidaVariant, BidaMode, AiLevel;
import 'games/sudoku/presentation/sudoku_menu_screen.dart';
import 'games/sudoku/presentation/sudoku_game_screen.dart';
import 'games/sudoku/presentation/sudoku_history_screen.dart';
import 'games/sudoku/presentation/sudoku_stats_screen.dart';

final _settingsService = SettingsService.instance;

/// Reactive theme/locale wrapper that reads from Hive settings.
class GameHubApp extends StatefulWidget {
  const GameHubApp({super.key});

  @override
  State<GameHubApp> createState() => _GameHubAppState();
}

class _GameHubAppState extends State<GameHubApp> {
  final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, __) => SettingsScreen(settings: _settingsService),
      ),
      GoRoute(path: '/caro', builder: (_, __) => const CaroMenuScreen()),
      GoRoute(path: '/caro/game', builder: (_, __) => const CaroGameScreen()),
      GoRoute(
          path: '/caro/lan/host', builder: (_, __) => const CaroLanHostScreen()),
      GoRoute(
          path: '/caro/lan/join', builder: (_, __) => const CaroLanJoinScreen()),
      GoRoute(
          path: '/caro/history', builder: (_, __) => const CaroHistoryScreen()),
      GoRoute(path: '/caro/stats', builder: (_, __) => const CaroStatsScreen()),
      GoRoute(
        path: '/caro/replay',
        builder: (_, state) {
          final record = state.extra as GameRecord;
          return CaroReplayScreen(record: record);
        },
      ),
      GoRoute(path: '/bida', builder: (_, __) => const BidaMenuScreen()),
      GoRoute(path: '/bida/stats', builder: (_, __) => const BidaStatsScreen()),
      GoRoute(
        path: '/bida/play',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BidaGameScreen(
            variant: extra['variant'] as BidaVariant,
            mode: extra['mode'] as BidaMode,
            aiLevel: extra['aiLevel'] as AiLevel?,
          );
        },
      ),
      GoRoute(path: '/sudoku', builder: (_, __) => const SudokuMenuScreen()),
      GoRoute(path: '/sudoku/game', builder: (_, __) => const SudokuGameScreen()),
      GoRoute(path: '/sudoku/history', builder: (_, __) => const SudokuHistoryScreen()),
      GoRoute(path: '/sudoku/stats', builder: (_, __) => const SudokuStatsScreen()),
    ],
  );

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _themeMode = _settingsService.themeMode;
    _locale = _settingsService.locale;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Game Hub',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      routerConfig: _router,
    );
  }
}
