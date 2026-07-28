import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

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

  /// Default habits created on first launch
  static final List<Habit> defaultHabits = [
    Habit(id: 'water', name: 'Drink Water', emoji: '💧', colorValue: 0xFF00CC52),
    Habit(id: 'walk', name: 'Walk 10k Steps', emoji: '🚶', colorValue: 0xFFFF9500),
    Habit(id: 'veggies', name: '5 Veggies', emoji: '🥗', colorValue: 0xFF34C759),
  ];

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('habits');
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      habits
        ..clear()
        ..addAll(list.map((e) => Habit.fromJson(Map<String, dynamic>.from(e))));
    } else {
      habits.addAll(defaultHabits.map((h) => Habit(
        id: h.id,
        name: h.name,
        emoji: h.emoji,
        colorValue: h.colorValue,
      )));
      await save(notify: false);
    }

    // Load water log
    final waterRaw = p.getString('water_log');
    if (waterRaw != null && waterRaw.isNotEmpty) {
      final decoded = jsonDecode(waterRaw) as Map<String, dynamic>;
      _waterLog.clear();
      decoded.forEach((k, v) => _waterLog[k] = v as int);
    }
    waterGoal = p.getInt('water_goal') ?? 8;

    _loaded = true;
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
  }

  Future<void> update(Habit h) async {
    await save();
  }

  Future<void> remove(Habit h) async {
    habits.removeWhere((x) => x.id == h.id);
    await save();
  }

  /// Water tracking
  void addWater() {
    final key = dateKey(DateTime.now());
    _waterLog[key] = (_waterLog[key] ?? 0) + 1;
    notifyListeners();
    save(notify: false);
  }

  void removeWater() {
    final key = dateKey(DateTime.now());
    if ((_waterLog[key] ?? 0) > 0) {
      _waterLog[key] = (_waterLog[key] ?? 1) - 1;
      notifyListeners();
      save(notify: false);
    }
  }

  void setWaterGoal(int goal) {
    waterGoal = goal;
    save();
  }

  /// Free tier habit limit
  static const int freeHabitLimit = 3;

  /// Check if user is subscribed (Pro)
  static Future<bool> isSubscribed() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('subscribed') ?? false;
  }

  /// Whether the free habit limit has been reached
  bool get habitLimitReached => habits.length >= freeHabitLimit;

  /// Today's active habits (not paused and due today)
  List<Habit> get todayHabits =>
      habits.where((h) => !h.paused && h.isDueOn(DateTime.now())).toList();

  /// Today's completed habits count
  int get todayCompleted => todayHabits.where((h) => h.isCompleted(DateTime.now())).length;

  /// Total streak power (sum of all habits)
  int get totalStreakPower => habits.fold<int>(0, (sum, h) => sum + h.currentStreak());

  /// Best streak across all habits
  int get bestStreakOverall {
    if (habits.isEmpty) return 0;
    return habits.map((h) => h.bestStreak()).reduce(max);
  }
}
