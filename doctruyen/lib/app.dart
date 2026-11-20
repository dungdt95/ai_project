import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/data_providers.dart';
import 'features/import/import_controller.dart';
import 'features/library/library_screen.dart';
import 'services/system_channel.dart';

class DocTruyenApp extends ConsumerStatefulWidget {
  const DocTruyenApp({super.key});

  @override
  ConsumerState<DocTruyenApp> createState() => _DocTruyenAppState();
}

class _DocTruyenAppState extends ConsumerState<DocTruyenApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<SharedFile>? _sub;

  @override
  void initState() {
    super.initState();
    final channel = ref.read(systemChannelProvider);
    _sub = channel.sharedFiles.listen(_handleShared);
    unawaited(
      channel.initialSharedFile().then((f) {
        if (f != null) _handleShared(f);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// Tệp từ "Mở bằng"/"Chia sẻ" của Android: nhập luôn vào thư viện.
  void _handleShared(SharedFile f) {
    // Đợi khung hình đầu để có Navigator/ScaffoldMessenger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKey.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(ImportController.importPath(ctx, ref, f.path, f.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: const LibraryScreen(),
    );
  }
}
