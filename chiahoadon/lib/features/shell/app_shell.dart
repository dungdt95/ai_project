import 'package:flutter/material.dart';


import '../bills/list/bills_screen.dart';
import '../home/home_screen.dart';
import '../stats/stats_screen.dart';
import 'more_screen.dart';

/// Khung điều hướng chính: 4 tab ở đáy màn hình (PLAN §5.1).
///
/// Ba tab đầu là chỗ dành sẵn cho các phase sau. Dựng khung ngay từ Phase 3 để
/// các màn hình thật chỉ cần thay vào đúng chỗ, không phải đổi lại điều hướng.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    HomeScreen(),
    BillsScreen(),
    StatsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giữ nguyên trạng thái cuộn và ô tìm kiếm của từng tab khi
      // người dùng chuyển qua lại.
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Khác',
          ),
        ],
      ),
    );
  }
}

