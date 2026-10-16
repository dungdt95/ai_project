import 'package:flutter/material.dart';

import 'features/invoices/invoices_screen.dart';
import 'features/items/items_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _screens = [
    ItemsScreen(),
    InvoicesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.local_drink_outlined), label: 'Mặt hàng'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Hóa đơn'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Báo cáo'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Cài đặt'),
        ],
      ),
    );
  }
}
