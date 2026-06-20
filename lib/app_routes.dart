class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const homeDaily = '/home/daily';
  static const homeCalendar = '/home/calendar';
  static const homeMonthly = '/home/monthly';
  static const income = '/income';
  static const reports = '/reports';
  static const accounts = '/accounts';
  static const accountDetailPrefix = '/accounts/';
  static const settings = '/settings';

  static String accountDetail(String accountName) {
    return '$accountDetailPrefix${Uri.encodeComponent(accountName)}';
  }

  static String? accountNameFromRoute(String route) {
    if (!route.startsWith(accountDetailPrefix) ||
        route.length <= accountDetailPrefix.length) {
      return null;
    }
    return Uri.decodeComponent(route.substring(accountDetailPrefix.length));
  }

  static String homeRouteForTab(int index) {
    return switch (index) {
      1 => homeCalendar,
      2 => homeMonthly,
      _ => homeDaily,
    };
  }

  static int homeTabForRoute(String? route) {
    return switch (route) {
      homeCalendar => 1,
      homeMonthly => 2,
      _ => 0,
    };
  }
}
