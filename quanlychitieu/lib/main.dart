import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'data/repositories/loan_repository.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestPermission();
  await LoanRepository().checkAndMarkOverdue();
  runApp(const ProviderScope(child: App()));
}
