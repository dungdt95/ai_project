import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_themes.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';
import 'features/deposits/presentation/deposits_screen.dart';
import 'features/loans/presentation/loans_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/calendar/presentation/calendar_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/presentation/categories_screen.dart';
import 'features/settings/presentation/banks_screen.dart';
import 'features/settings/presentation/borrowers_screen.dart';
import 'features/settings/presentation/theme_settings_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(themePreferenceProvider);
    final preset = getPresetByKey(pref.colorName);

    return MaterialApp(
      title: 'Quản lý Thu Chi',
      debugShowCheckedModeBanner: false,
      themeMode: pref.mode,
      theme: buildAppTheme(preset.seedColor, Brightness.light),
      darkTheme: buildAppTheme(preset.seedColor, Brightness.dark),
      home: const MainShell(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/categories': (_) => const CategoriesScreen(),
        '/banks': (_) => const BanksScreen(),
        '/borrowers': (_) => const BorrowersScreen(),
        '/theme': (_) => const ThemeSettingsScreen(),
      },
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    // Refresh data khi quay lại tab Tổng quan hoặc Báo cáo
    if (index == 0 && _currentIndex != 0) {
      ref.read(homeRefreshProvider.notifier).state++;
    }
    if (index == 5 && _currentIndex != 5) {
      ref.read(reportsRefreshProvider.notifier).state++;
    }
    setState(() => _currentIndex = index);
  }

  static const _screens = [
    HomeScreen(),
    TransactionsScreen(),
    CalendarScreen(),
    DepositsScreen(),
    LoansScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Giao dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Tiền gửi',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Cho vay',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Báo cáo',
          ),
        ],
      ),
    );
  }
}
