import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Xoá just_audio_cache để luôn nạp âm thanh mới nhất từ asset APK
  try {
    final tempDir = await getTemporaryDirectory();
    final audioCache = Directory('${tempDir.path}/just_audio_cache');
    if (await audioCache.exists()) {
      await audioCache.delete(recursive: true);
    }
  } catch (_) {}

  final storage = await Storage.open();
  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const BeVuiApp(),
  ));
}
