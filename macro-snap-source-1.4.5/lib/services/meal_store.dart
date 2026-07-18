import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/meal_record.dart';

class MealStore {
  static final MealStore _instance = MealStore._();
  static MealStore get instance => _instance;
  MealStore._();

  final ValueNotifier<int> changeNotifier = ValueNotifier(0);

  List<MealRecord> _meals = [];
  bool _loaded = false;

  List<MealRecord> get todayMeals =>
    _meals.where((m) => m.isToday).toList()..sort((a, b) => b.date.compareTo(a.date));

  List<MealRecord> get allMeals => List.unmodifiable(_meals);

  int get todayCalories => todayMeals.fold(0, (sum, m) => sum + m.calories);
  double get todayProtein => todayMeals.fold(0.0, (sum, m) => sum + m.protein);
  double get todayCarbs => todayMeals.fold(0.0, (sum, m) => sum + m.carbs);
  double get todayFats => todayMeals.fold(0.0, (sum, m) => sum + m.fats);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/meals.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) {
          _meals = [];
        } else {
          final data = jsonDecode(raw);
          if (data is List) {
            _meals = data
                .whereType<Map<String, dynamic>>()
                .map((e) => MealRecord.fromJson(e))
                .toList();
          }
        }
      }
    } catch (_) {
      _meals = [];
    }
    _loaded = true;
  }

  Future<void> add(MealRecord meal) async {
    _meals.add(meal);
    await _save();
    changeNotifier.value++;
  }

  Future<void> remove(String id) async {
    _meals.removeWhere((m) => m.id == id);
    await _save();
    changeNotifier.value++;
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/meals.json');
      await file.writeAsString(jsonEncode(_meals.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }
}
