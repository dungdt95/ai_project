import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_provider.dart';
import 'features/shell/app_lock_gate.dart';
import 'features/shell/app_shell.dart';

class ChiaHoaDonApp extends ConsumerWidget {
  const ChiaHoaDonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Cổng khóa bọc ngoài cùng để mọi màn hình, kể cả màn đang mở dở khi
      // người dùng rời app, đều bị che khi khóa bật.
      home: const AppLockGate(child: AppShell()),
    );
  }
}
