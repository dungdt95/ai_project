import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minishop/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App shell loads with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Mặt hàng'), findsWidgets);
    expect(find.text('Hóa đơn'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}
