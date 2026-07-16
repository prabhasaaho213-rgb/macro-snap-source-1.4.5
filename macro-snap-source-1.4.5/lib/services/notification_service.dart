import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Permission.notification.request();
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
    } catch (_) {
      // Ignore notification initialization failures; app should still run.
    }

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {}

  Future<void> showSubscribed() async {
    await _plugin.show(
      1,
      'Welcome to MacroSnap Pro!',
      'Your subscription is active. Start tracking your macros now.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_subscription',
          'Subscription',
          channelDescription: 'Payment & subscription notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleDailyReminder() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 20, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      4,
      'Time to log your meals!',
      'Snap a photo of what you ate today and track your macros.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_reminder',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log meals',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleWeeklySummary() async {
    final now = DateTime.now();
    final daysUntilSunday = 7 - now.weekday;
    var sunday = DateTime(now.year, now.month, now.day + daysUntilSunday, 19, 0);
    if (sunday.isBefore(now)) {
      sunday = sunday.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      5,
      'Your weekly nutrition summary',
      'See how your macros looked this week. Open MacroSnap to check.',
      tz.TZDateTime.from(sunday, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_weekly',
          'Weekly Summary',
          channelDescription: 'Weekly nutrition summary notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleExpiryReminder(String subscribedDate) async {
    final start = DateTime.parse(subscribedDate);
    final reminderDate = start.add(const Duration(days: 27));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    await _plugin.zonedSchedule(
      2,
      'Pro expires in 3 days',
      'Renew to keep unlimited access to AI meal analysis & tracking.',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_expiry',
          'Expiry Reminder',
          channelDescription: 'Subscription expiry reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleExpired(String subscribedDate) async {
    final start = DateTime.parse(subscribedDate);
    final expiredDate = start.add(const Duration(days: 30));
    final now = DateTime.now();
    if (expiredDate.isBefore(now)) return;

    await _plugin.zonedSchedule(
      3,
      'Your Pro subscription has expired',
      'Renew now for ₹29 to get full access again.',
      tz.TZDateTime.from(expiredDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_expiry',
          'Expiry Reminder',
          channelDescription: 'Subscription expiry reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleAllForSubscriber(String subscribedDate) async {
    await cancelAll();
    await scheduleDailyReminder();
    await scheduleWeeklySummary();
    await scheduleStreakReminder();
    await scheduleExpiryReminder(subscribedDate);
    await scheduleExpired(subscribedDate);
  }

  Future<void> scheduleStreakReminder() async {
    final now = DateTime.now();
    var reminderTime = DateTime(now.year, now.month, now.day, 19, 30);
    if (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      6,
      "Don't break your chain! 🔥",
      'You haven\'t logged a meal today. Snap a photo to keep your streak alive.',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_reminder',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log meals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
