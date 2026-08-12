import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import 'meal_sync_service.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class HabitStore extends ChangeNotifier {
  static final HabitStore _instance = HabitStore._();
  static HabitStore get instance => _instance;
  HabitStore._();

  final List<Habit> habits = [];
  bool _loaded = false;

  /// Water intake tracking (glasses per day)
  int waterGoal = 8;
  int get waterToday => _waterLog[dateKey(DateTime.now())] ?? 0;
  final Map<String, int> _waterLog = {};

  /// Public read-only view of the water log (for cloud sync).
  Map<String, int> get waterLog => Map.unmodifiable(_waterLog);

  /// Whether cloud restore has been attempted
  bool _cloudRestored = false;
  /// Whether a cloud restore is currently in progress
  bool _restoring = false;
  /// The in-flight restore, so [reload] can await it before re-fetching
  /// for a newly active account.
  Future<void>? _restoreFuture;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();

    // Habits — parsed defensively: a corrupted JSON string must reset the
    // list, never crash the app at launch (a throw here used to kill main()
    // before runApp(), leaving the app unable to open).
    try {
      final raw = p.getString('habits');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          habits
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((e) => Habit.fromJson(Map<String, dynamic>.from(e))));
        }
      }
    } catch (_) {
      habits.clear();
    }

    // Water log — same defensive parsing.
    try {
      final waterRaw = p.getString('water_log');
      if (waterRaw != null && waterRaw.isNotEmpty) {
        final decoded = jsonDecode(waterRaw);
        if (decoded is Map) {
          _waterLog.clear();
          decoded.forEach((k, v) {
            if (v is num) _waterLog[k.toString()] = v.toInt();
          });
        }
      }
    } catch (_) {
      _waterLog.clear();
    }
    waterGoal = p.getInt('water_goal') ?? 8;

    _loaded = true;

    // Restore from cloud backup in the background so a slow or sleeping
    // backend never blocks the app from opening.
    unawaited(_restoreFromCloud());
  }

  /// Force a full reload from local + cloud (used after login/logout so
  /// the cloud data for the newly active account is pulled in).
  Future<void> reload() async {
    // If a background restore is still in flight from the previous account,
    // let it finish before clearing — otherwise its late merge would pollute
    // the freshly loaded state AND set `_cloudRestored`, blocking the new
    // account's own cloud fetch until the next restart.
    await _restoreFuture;
    _loaded = false;
    _cloudRestored = false;
    habits.clear();
    _waterLog.clear();
    await load();
    notifyListeners();
  }

  /// Merge habits + water log from cloud backup (only adds missing data).
  /// Reentrant-safe: returns the in-flight future if a restore is already
  /// running, so concurrent callers can await the same operation.
  Future<void> _restoreFromCloud() {
    if (_cloudRestored || _restoring) {
      return _restoreFuture ?? Future.value();
    }
    _restoring = true;
    _restoreFuture = _doRestoreFromCloud();
    return _restoreFuture!;
  }

  Future<void> _doRestoreFromCloud() async {
    try {
      final cloud = await MealSyncService.fetchHabits();
      if (cloud != null) {
        bool changed = false;

        // Restore habits not already present locally
        final cloudHabits = (cloud['habits'] as List<Map<String, dynamic>>)
            .map((e) => Habit.fromJson(e))
            .toList();
        final localIds = habits.map((h) => h.id).toSet();
        for (final habit in cloudHabits) {
          if (!localIds.contains(habit.id)) {
            habits.add(habit);
            changed = true;
          }
        }

        // Restore water log entries not already present locally
        final cloudWaterLog = cloud['waterLog'] as Map<String, int>;
        final localWaterKeys = _waterLog.keys.toSet();
        for (final entry in cloudWaterLog.entries) {
          if (!localWaterKeys.contains(entry.key)) {
            _waterLog[entry.key] = entry.value;
            changed = true;
          }
        }

        if (changed) {
          await save(notify: true);
        }
      }

      // CRITICAL: reminders for cloud-restored habits were never scheduled.
      // restoreAllReminders() at startup only sees the LOCAL list, and the
      // cloud merge lands afterwards — so after a reinstall / data clear /
      // new device, every cloud habit had reminderEnabled=true but ZERO
      // alarms behind it. Re-arm all enabled habits here (idempotent —
      // zonedSchedule replaces by id).
      for (final h in habits) {
        if (h.reminderEnabled) {
          await NotificationService().scheduleHabitReminder(h);
        }
      }
    } catch (_) {}
    _restoring = false;
    _cloudRestored = true;
    _restoreFuture = null;
  }

  Future<void> save({bool notify = true}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('habits', jsonEncode(habits.map((h) => h.toJson()).toList()));
    await p.setString('water_log', jsonEncode(_waterLog));
    await p.setInt('water_goal', waterGoal);
    if (notify) notifyListeners();
  }

  Future<void> add(Habit h) async {
    habits.add(h);
    await save();
    _syncToCloud();
    if (h.reminderEnabled) {
      await NotificationService().scheduleHabitReminder(h);
    }
  }

  Future<void> update(Habit h, {bool syncReminder = true}) async {
    await save();
    _syncToCloud();
    // Re-sync reminder when the habit's schedule or toggle changes.
    // Completion toggles (swipe/tap on a mission card) pass syncReminder:
    // false so we don't cancel+recreate the daily zonedSchedule on every
    // swipe — the schedule only changes on edit.
    if (syncReminder) {
      if (h.reminderEnabled) {
        await NotificationService().scheduleHabitReminder(h);
      } else {
        await NotificationService().cancelHabitReminder(h);
      }
    }
  }

  Future<void> remove(Habit h) async {
    await NotificationService().cancelHabitReminder(h);
    habits.removeWhere((x) => x.id == h.id);
    await save();
    _syncToCloud();
  }

  /// Mark a habit as completed for today (used by the notification's
  /// "Mark done" action), persist, sync to cloud, clear any snoozed
  /// reminder, and push today's upcoming daily reminder to tomorrow so the
  /// habit never re-reminds the same day.
  Future<void> completeToday(Habit h) async {
    final key = dateKey(DateTime.now());
    if (!h.completedDates.contains(key)) {
      h.completedDates.add(key);
      h.skippedDates.remove(key);
    }
    await save();
    _syncToCloud();
    await NotificationService().cancelHabitReminderSnooze(h);
    await NotificationService().rescheduleHabitReminderFromTomorrow(h);
  }



  /// Water tracking
  void addWater() {
    final key = dateKey(DateTime.now());
    _waterLog[key] = (_waterLog[key] ?? 0) + 1;
    notifyListeners();
    save(notify: false);
    _syncToCloud();
  }

  void removeWater() {
    final key = dateKey(DateTime.now());
    if ((_waterLog[key] ?? 0) > 0) {
      _waterLog[key] = (_waterLog[key] ?? 1) - 1;
      notifyListeners();
      save(notify: false);
      _syncToCloud();
    }
  }

  void setWaterGoal(int goal) {
    waterGoal = goal;
    save();
    _syncToCloud();
  }

  /// Fire-and-forget: sync habits + water log to cloud.
  /// Skips if a cloud restore is still in progress to avoid overwriting.
  void _syncToCloud() {
    if (_restoring) return;
    MealSyncService.syncHabits(
      habitsJson: habits.map((h) => h.toJson()).toList(),
      waterLog: Map.from(_waterLog),
      waterGoal: waterGoal,
    );
  }

  /// Free tier habit limit
  static const int freeHabitLimit = 3;

  /// Check if user is subscribed (Pro)
  static Future<bool> isSubscribed() async {
    await SubscriptionService.instance.load();
    return SubscriptionService.instance.isSubscribed;
  }

  /// Whether the free habit limit has been reached
  bool get habitLimitReached => habits.length >= freeHabitLimit;

  /// Today's active habits (not paused and due today)
  List<Habit> get todayHabits =>
      habits.where((h) => !h.paused && h.isDueOn(DateTime.now())).toList();

  /// Today's completed habits count
  int get todayCompleted => todayHabits.where((h) => h.isCompleted(DateTime.now())).length;

  /// Best current streak across all habits (most consecutive days)
  int get totalStreakPower {
    if (habits.isEmpty) return 0;
    return habits.map((h) => h.currentStreak()).reduce(max);
  }
}
