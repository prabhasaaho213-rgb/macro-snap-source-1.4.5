import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_nav.dart';
import '../models/habit.dart';
import 'habit_reminder_service.dart';
import 'habit_store.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// The name of the device timezone (e.g. "Asia/Kolkata"), persisted so the
  /// background isolate (which re-creates everything from scratch) can set
  /// `tz.local` correctly for snooze scheduling.
  static const _keyTz = 'device_timezone_name';

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Request POST_NOTIFICATIONS (Android 13+). Never let a failure or
      // denial here block plugin/channel setup — otherwise every scheduled
      // reminder silently dies for the rest of the session.
      try {
        await Permission.notification.request();
      } catch (_) {}
      tz_data.initializeTimeZones();
      // CRITICAL: without this, tz.local stays UTC and every scheduled
      // reminder fires at the wrong wall-clock time (e.g. 5.5h late in IST).
      final tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(tzName));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyTz, tzName);
      } catch (_) {}

      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );
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
        onDidReceiveBackgroundNotificationResponse:
            handleHabitReminderActionBackground,
      );
      _initialized = true;
    } catch (e) {
      // Ignore notification initialization failures; app should still run.
      debugPrint('❌ NotificationService.init failed: $e');
    }
  }

  /// Handles taps and action buttons on notifications.
  ///
  /// Habit reminders carry the habit id as the payload, so we can snooze,
  /// mark the habit done, or open the Habits tab right from the shade.
  void _onNotificationTap(NotificationResponse response) {
    final actionId = response.actionId;
    final habitId = response.payload;

    // Only habit reminders carry a habit id payload.
    if (habitId == null || habitId.isEmpty) return;

    if (actionId == HabitReminderService.snoozeAction) {
      _snoozeHabit(habitId);
    } else if (actionId == HabitReminderService.doneAction) {
      _completeHabit(habitId);
    } else {
      // Plain tap on the notification -> open the Habits tab.
      openShellTab(2);
    }
  }

  Habit? _findHabit(String habitId) {
    for (final h in HabitStore.instance.habits) {
      if (h.id == habitId) return h;
    }
    return null;
  }

  Future<void> _snoozeHabit(String habitId) async {
    try {
      await HabitStore.instance.load();
      final habit = _findHabit(habitId);
      if (habit == null) return;
      await HabitReminderService.snooze(habit, _plugin);
    } catch (_) {
      // Never let a notification action crash the app.
    }
  }

  Future<void> _completeHabit(String habitId) async {
    try {
      await HabitStore.instance.load();
      final habit = _findHabit(habitId);
      if (habit == null) return;
      await HabitStore.instance.completeToday(habit);
    } catch (_) {
      // Never let a notification action crash the app.
    }
  }

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
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Sends an immediate test notification so the user (and support) can
  /// verify the whole pipeline — permission, channel, plugin init — in one
  /// tap. Throws with a clear message if anything is wrong; the caller
  /// surfaces it.
  Future<void> sendTestNotification() async {
    if (!_initialized) await init();
    await _plugin.show(
      99,
      'MacroSnap test notification',
      'Notifications are working correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_reminder',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log meals',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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
      'Time to log your meals',
      'Snap a photo of your meal to track calories and macros.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_reminder',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log meals',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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
    var sunday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      19,
      0,
    );
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
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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
      'Keep your streak alive',
      'You haven\'t logged a meal today. Snap a photo to keep your streak going.',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'macro_snap_reminder',
          'Meal Reminders',
          channelDescription: 'Daily reminders to log meals',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF059669),
          icon: '@drawable/ic_notification',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
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

  /// Schedule a reminder for a single habit (daily at the habit's set time).
  Future<void> scheduleHabitReminder(Habit h) async {
    try {
      await HabitReminderService.schedule(h, _plugin);
    } catch (_) {}
  }

  /// Cancel the reminder for a single habit.
  Future<void> cancelHabitReminder(Habit h) async {
    try {
      await HabitReminderService.cancel(h, _plugin);
    } catch (_) {}
  }

  /// Cancel just the one-off snoozed reminder (keeps the daily one).
  Future<void> cancelHabitReminderSnooze(Habit h) async {
    try {
      await HabitReminderService.cancelSnooze(h, _plugin);
    } catch (_) {}
  }

  /// Suppress today's remaining daily reminder for [h] by cancelling the
  /// repeating schedule and re-creating it from tomorrow. Called after the
  /// habit is marked done today so it never re-reminds the same day.
  Future<void> rescheduleHabitReminderFromTomorrow(Habit h) async {
    try {
      await HabitReminderService.rescheduleTomorrow(h, _plugin);
    } catch (_) {}
  }

  /// Re-schedule reminders for all habits with reminders enabled.
  Future<void> scheduleAllHabitReminders(List<Habit> habits) async {
    for (final h in habits) {
      await scheduleHabitReminder(h);
    }
  }

  /// Returns a human-readable list of every reminder currently scheduled on
  /// the device (id, title, next fire time). Used by the Settings diagnostic
  /// so "habit reminders not working" can be told apart from "habit
  /// reminders were never scheduled".
  Future<List<String>> pendingReminderSummary() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      requests.sort((a, b) => a.id.compareTo(b.id));
      return requests
          .map((r) => '#${r.id} ${r.title ?? ''}${r.payload == null || r.payload!.isEmpty ? '' : ' (payload: ${r.payload})'}')
          .toList();
    } catch (e) {
      return ['Could not read pending requests: $e'];
    }
  }

  /// Full startup safety net: re-create every reminder so a lost alarm
  /// (reinstall, app update, force-stop) can never silently disable
  /// notifications. Each reminder restores independently — one failure
  /// never blocks the others. Subscribers additionally re-arm the expiry
  /// reminders and the weekly summary (same ids are replaced, idempotent).
  Future<void> restoreAllReminders(
    List<Habit> habits, {
    String? subscribedDate,
  }) async {
    await _safe(scheduleDailyReminder);
    await _safe(scheduleStreakReminder);
    await _safe(() => scheduleAllHabitReminders(habits));
    if (subscribedDate != null && subscribedDate.isNotEmpty) {
      await _safe(() => scheduleExpiryReminder(subscribedDate));
      await _safe(() => scheduleExpired(subscribedDate));
      await _safe(scheduleWeeklySummary);
    }
  }

  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('❌ reminder restore failed: $e');
    }
  }
}
