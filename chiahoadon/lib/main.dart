import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/data_providers.dart';
import 'data/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mở DB trước khi dựng UI: app chạy hoàn toàn offline nên bước này chỉ là
  // đọc tệp cục bộ, mất vài chục mili giây. Đổi lại, mọi provider phía sau là
  // đồng bộ và không màn hình nào phải hiện trạng thái "đang tải dữ liệu".
  final database = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const ChiaHoaDonApp(),
    ),
  );
}
