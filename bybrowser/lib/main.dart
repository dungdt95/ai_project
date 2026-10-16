import 'package:flutter/material.dart';

import 'app.dart';
import 'core/recent/recent_files.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final recents = RecentFilesStore();
  final settings = AppSettings();
  await Future.wait([recents.load(), settings.load()]);
  runApp(ByBrowserApp(recents: recents, settings: settings));
}
