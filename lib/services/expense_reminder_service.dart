import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily local notification to prompt logging expenses (mobile/desktop only; not web).
class ExpenseReminderService {
  ExpenseReminderService._();
  static final ExpenseReminderService instance = ExpenseReminderService._();

  static const int notificationId = 91001;
  static const String channelId = 'expense_daily_reminder';

  static const String _prefsEnabled = 'expense_reminder_enabled';
  static const String _prefsHour = 'expense_reminder_hour';
  static const String _prefsMinute = 'expense_reminder_minute';

  static const int defaultHour = 21;
  static const int defaultMinute = 0;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set from [main] before [initialize]. Invoked when user taps the daily reminder.
  static VoidCallback? onReminderNotificationTap;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.id == notificationId) {
          onReminderNotificationTap?.call();
        }
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Daily expense reminder',
        description: 'Reminder to add today\'s expenses',
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  /// Call when enabling reminders or from Settings after OS denied then fixed.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();

    var androidOk = true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted == false) androidOk = false;
    }
    var iosOk = true;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      if (granted != true) iosOk = false;
    }
    return androidOk && iosOk;
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsEnabled) ?? false;
  }

  Future<TimeOfDay> reminderTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: p.getInt(_prefsHour) ?? defaultHour,
      minute: p.getInt(_prefsMinute) ?? defaultMinute,
    );
  }

  Future<void> setReminderEnabled(bool enabled) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsEnabled, enabled);
    if (enabled) {
      await requestPermissions();
      await scheduleDailyReminder();
    } else {
      await cancelReminder();
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    if (kIsWeb) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsHour, time.hour);
    await p.setInt(_prefsMinute, time.minute);
    if (!_initialized) await initialize();
    if (await isEnabled()) {
      await scheduleDailyReminder();
    }
  }

  /// Re-apply schedule after app start (and optional future: boot receiver).
  Future<void> rescheduleIfEnabled() async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    if (await isEnabled()) {
      await scheduleDailyReminder();
    }
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay t) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      t.hour,
      t.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();

    await cancelReminder();

    final time = await reminderTime();
    final scheduled = _nextInstanceOf(time);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      'Daily expense reminder',
      channelDescription: 'Nudge to add today\'s expenses',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      notificationId,
      'Time to log expenses',
      'Add today\'s spending so your tracker stays up to date.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_expense_reminder',
    );
  }

  /// True once when the app was opened by tapping the expense reminder (cold start).
  Future<bool> launchedFromReminderNotification() async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return false;
    final response = details.notificationResponse;
    return response != null && response.id == notificationId;
  }

  Future<void> cancelReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(notificationId);
  }
}
