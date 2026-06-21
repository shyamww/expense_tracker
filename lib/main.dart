import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_routes.dart';
import 'providers/expense_provider.dart';
import 'providers/income_provider.dart';
import 'providers/category_provider.dart';
import 'providers/account_provider.dart';
import 'providers/app_lock_provider.dart';
import 'providers/app_navigation_hub.dart';
import 'providers/cloud_auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/income_screen.dart';
import 'screens/report_screen.dart';
import 'screens/accounts_list_screen.dart';
import 'screens/account_detail_screen.dart';
import 'screens/cloud_sync_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/lock_screen.dart';
import 'services/browser_route.dart';
import 'services/expense_reminder_service.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  final appNavHub = AppNavigationHub();
  final themeProvider = ThemeProvider();
  final cloudAuthProvider = CloudAuthProvider();
  await themeProvider.load();
  if (!kIsWeb) {
    ExpenseReminderService.onReminderNotificationTap =
        () => appNavHub.requestHomeDashboard();
    await ExpenseReminderService.instance.initialize();
    await ExpenseReminderService.instance.rescheduleIfEnabled();
  }
  final initialRoute =
      kIsWeb ? readBrowserRoute(AppRoutes.homeDaily) : AppRoutes.homeDaily;
  if (kIsWeb) replaceBrowserRoute(initialRoute);

  runApp(ExpenseTrackerApp(
    navHub: appNavHub,
    themeProvider: themeProvider,
    cloudAuthProvider: cloudAuthProvider,
    initialRoute: initialRoute,
  ));
}

class ExpenseTrackerApp extends StatelessWidget {
  ExpenseTrackerApp({
    super.key,
    required this.navHub,
    required this.themeProvider,
    required this.cloudAuthProvider,
    required this.initialRoute,
  });

  final AppNavigationHub navHub;
  final ThemeProvider themeProvider;
  final CloudAuthProvider cloudAuthProvider;
  final String initialRoute;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: brightness,
      surface: isDark ? const Color(0xFF171B26) : Colors.white,
    );
    final background =
        isDark ? const Color(0xFF0D111A) : const Color(0xFFF8F9FB);
    final surface = isDark ? const Color(0xFF171B26) : Colors.white;
    final inputFill = isDark ? const Color(0xFF111827) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerColor: isDark ? const Color(0xFF2A3142) : const Color(0xFFE5E7EB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF30384A) : const Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF30384A) : const Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
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

  Route<dynamic> _buildRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.homeDaily;
    final accountName = AppRoutes.accountNameFromRoute(routeName);
    final Widget page = accountName != null
        ? AccountDetailScreen(accountName: accountName)
        : switch (routeName) {
            AppRoutes.root ||
            AppRoutes.home ||
            AppRoutes.homeDaily =>
              const HomeScreen(
                initialTabIndex: 0,
              ),
            AppRoutes.homeCalendar => const HomeScreen(initialTabIndex: 1),
            AppRoutes.homeMonthly => const HomeScreen(initialTabIndex: 2),
            AppRoutes.income => const IncomeScreen(),
            AppRoutes.reports => const ReportScreen(),
            AppRoutes.accounts => const AccountsListScreen(),
            AppRoutes.cloudSync => const CloudSyncScreen(),
            AppRoutes.settings => const SettingsScreen(),
            _ => const HomeScreen(initialTabIndex: 0),
          };

    if (kIsWeb) {
      return PageRouteBuilder<dynamic>(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => page,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppNavigationHub>.value(value: navHub),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<CloudAuthProvider>.value(
          value: cloudAuthProvider,
        ),
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
            initialRoute: initialRoute,
            navigatorKey: _navigatorKey,
            onGenerateRoute: _buildRoute,
            onGenerateInitialRoutes: (initialRoute) => [
              _buildRoute(RouteSettings(name: initialRoute)),
            ],
            builder: (context, child) {
              if (!lock.isReady) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final body = Stack(
                children: [
                  child!,
                  if (lock.shouldShowLock) const LockScreen(),
                ],
              );
              if (!kIsWeb) return body;
              return BrowserRouteSync(
                navigatorKey: _navigatorKey,
                initialRoute: initialRoute,
                child: body,
              );
            },
          );
        },
      ),
    );
  }
}

class BrowserRouteSync extends StatefulWidget {
  const BrowserRouteSync({
    super.key,
    required this.navigatorKey,
    required this.initialRoute,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final Widget child;

  @override
  State<BrowserRouteSync> createState() => _BrowserRouteSyncState();
}

class _BrowserRouteSyncState extends State<BrowserRouteSync> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      replaceBrowserRoute(widget.initialRoute);
    });
    _subscription =
        browserRouteChanges(AppRoutes.homeDaily).listen(_openBrowserRoute);
  }

  void _openBrowserRoute(String route) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
