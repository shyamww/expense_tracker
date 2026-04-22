import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/expense_provider.dart';
import 'providers/income_provider.dart';
import 'providers/category_provider.dart';
import 'providers/account_provider.dart';
import 'providers/app_lock_provider.dart';
import 'providers/app_navigation_hub.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'services/expense_reminder_service.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 LOCK ORIENTATION HERE
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final appNavHub = AppNavigationHub();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  if (!kIsWeb) {
    ExpenseReminderService.onReminderNotificationTap =
        () => appNavHub.requestHomeDashboard();
    await ExpenseReminderService.instance.initialize();
    await ExpenseReminderService.instance.rescheduleIfEnabled();
  }
  runApp(ExpenseTrackerApp(navHub: appNavHub, themeProvider: themeProvider));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.navHub,
    required this.themeProvider,
  });

  final AppNavigationHub navHub;
  final ThemeProvider themeProvider;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: brightness,
      surface: isDark ? const Color(0xFF141824) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F131C) : const Color(0xFFF8F9FB),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF0F131C) : const Color(0xFFF8F9FB),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE5E7EB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF171C28) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppNavigationHub>.value(value: navHub),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => AppLockProvider()),
      ],
      child: Consumer2<ThemeProvider, AppLockProvider>(
        builder: (context, theme, lock, _) {
          return MaterialApp(
            title: 'Expense Tracker',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: theme.themeMode,
            builder: (context, child) {
              if (!lock.isReady) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return Stack(
                children: [
                  child!,
                  if (lock.shouldShowLock) const LockScreen(),
                ],
              );
            },
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
