import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'core/notification/notification_access.dart';
import 'core/notification/notification_callback_dispatcher.dart';
import 'features/invoices/invoices_controller.dart';
import 'features/items/items_controller.dart';
import 'features/settings/bank_accounts_controller.dart';
import 'features/settings/notification_apps_controller.dart';
import 'features/reports/reports_controller.dart';

void main() {
  runApp(const MyApp());
  _registerNotificationCallbackHandle();
}

/// Refreshes the background-isolate callback handle on every startup —
/// handles are derived from compiled code offsets and can change between
/// builds/installs, so the native side needs the current one each run.
void _registerNotificationCallbackHandle() {
  final handle =
      ui.PluginUtilities.getCallbackHandle(notificationCallbackDispatcher);
  if (handle != null) {
    NotificationAccess.setCallbackHandle(handle.toRawHandle());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemsController()),
        ChangeNotifierProvider(create: (_) => InvoicesController()),
        ChangeNotifierProvider(create: (_) => BankAccountsController()),
        ChangeNotifierProvider(create: (_) => NotificationAppsController()),
        ChangeNotifierProvider(create: (_) => ReportsController()),
      ],
      child: MaterialApp(
        title: 'Mini Shop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AppShell(),
      ),
    );
  }
}
