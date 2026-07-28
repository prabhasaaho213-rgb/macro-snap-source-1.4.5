import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/habit.dart';

class HabitReminderService {
  static int _notificationId(Habit h) {
    var value = 17;
    for (final codeUnit in h.id.codeUnits) {
      value = (value * 31 + codeUnit) & 0x7fffffff;
    }
    return value;
  }

  static Future<void> schedule(Habit h, FlutterLocalNotificationsPlugin notifications) async {
    if (!h.reminderEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, h.reminderHour, h.reminderMinute,
    );
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await notifications.zonedSchedule(
      _notificationId(h),
      'Habit reminder',
      'Time for ${h.name} ${h.emoji}',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit reminders',
          channelDescription: 'Reminders for your habits',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(Habit h, FlutterLocalNotificationsPlugin notifications) async {
    await notifications.cancel(_notificationId(h));
  }
}
