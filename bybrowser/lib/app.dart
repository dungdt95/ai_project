import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

import 'core/recent/recent_files.dart';
import 'core/settings/app_settings.dart';
import 'features/home/home_page.dart';

class ByBrowserApp extends StatelessWidget {
  const ByBrowserApp({super.key, required this.recents, required this.settings});

  final RecentFilesStore recents;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'ByBrowser',
        debugShowCheckedModeBanner: false,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          FlutterQuillLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
        darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
        themeMode: settings.themeMode,
        home: HomePage(recents: recents, settings: settings),
      ),
    );
  }
}
