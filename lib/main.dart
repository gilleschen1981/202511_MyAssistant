import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/core/theme/app_theme.dart';
import 'package:myassistant/data/services/notification_service.dart';
import 'package:myassistant/di/providers/database_provider.dart';
import 'package:myassistant/presentation/routes/app_router.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications for Android
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  // Run the app with Riverpod
  runApp(
    const ProviderScope(
      child: MyAssistantApp(),
    ),
  );
}

class MyAssistantApp extends ConsumerWidget {
  const MyAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize database on app start (Android only)
    final databaseAsync = ref.watch(databaseInitializerProvider);
    final router = ref.watch(routerProvider);

    return databaseAsync.when(
      data: (_) => MaterialApp.router(
        title: 'MyAssistant',
        debugShowCheckedModeBanner: false,

        // Router config
        routerConfig: router,

        // Theme
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
      ),
      loading: () => MaterialApp(
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColorLight,
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      error: (error, stack) => MaterialApp(
        home: _ErrorScreen(error: error.toString()),
      ),
    );
  }
}

/// Error screen for initialization errors
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
