import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/navigation/app_router.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/google_drive_service.dart';
import 'core/services/notification_service.dart';
import 'features/expenses/providers/expense_provider.dart';
import 'features/tasks/providers/task_provider.dart';
import 'features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.init();
  runApp(const DigitalCompanionApp());
}

class DigitalCompanionApp extends StatelessWidget {
  const DigitalCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize singleton services
    final localStorage = LocalStorageService();
    final driveService = GoogleDriveService();

    return MultiProvider(
      providers: [
        // Core
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: driveService),
        Provider.value(value: localStorage),

        // Features
        ChangeNotifierProvider(
          create: (_) => ExpenseProvider(localStorage, driveService),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(localStorage, driveService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'HiSaab',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
