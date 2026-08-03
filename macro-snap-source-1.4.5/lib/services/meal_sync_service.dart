import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_record.dart';
import 'gemini_service.dart';
import 'sync_status_service.dart';

/// Handles cloud backup/sync of ALL user data to the backend server.
/// Uses the user's 500MB backend database for storage.
///
/// Currently backs up:
/// - Meals (individual + bulk)
/// - Habits (full list + water log)
class MealSyncService {
  static String get _baseUrl => GeminiService.serverUrl;

  // ═══════════════════════════════════════════════════════════════
  // MEALS
  // ═══════════════════════════════════════════════════════════════

  /// Sync a single meal to the backend.
  static Future<bool> syncMeal(MealRecord meal) async {
    final phone = await _getPhone();
    if (phone == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/meals/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'meal': meal.toJson()}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        SyncStatusService.instance.reportSuccess();
        return true;
      }
      SyncStatusService.instance.reportFailure('Meal sync (HTTP ${resp.statusCode})');
      return false;
    } catch (e) {
      debugPrint('MealSyncService.syncMeal failed: $e');
      SyncStatusService.instance.reportFailure('Meal sync failed');
      return false;
    }
  }

  /// Remove a meal from cloud backup.
  static Future<bool> removeMeal(String mealId) async {
    final phone = await _getPhone();
    if (phone == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/meals/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'meal_id': mealId}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        SyncStatusService.instance.reportSuccess();
        return true;
      }
      SyncStatusService.instance.reportFailure('Meal remove (HTTP ${resp.statusCode})');
      return false;
    } catch (e) {
      debugPrint('MealSyncService.removeMeal failed: $e');
      SyncStatusService.instance.reportFailure('Meal remove failed');
      return false;
    }
  }

  /// Fetch all meals from cloud backup.
  static Future<List<MealRecord>> fetchMeals() async {
    final phone = await _getPhone();
    if (phone == null) return [];
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/meals/list/$phone'),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          // Report success only after the body parses as the expected shape,
          // so a 200-with-error-JSON never wrongly clears the banner.
          SyncStatusService.instance.reportSuccess();
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => MealRecord.fromJson(e))
              .toList();
        }
      } else {
        SyncStatusService.instance
            .reportFailure('Meal restore (HTTP ${resp.statusCode})');
      }
    } catch (e) {
      debugPrint('MealSyncService.fetchMeals failed: $e');
      SyncStatusService.instance.reportFailure('Meal restore failed');
    }
    return [];
  }

  /// Bulk sync all local meals to the backend.
  static Future<void> syncAllMeals(List<MealRecord> meals) async {
    for (final meal in meals) {
      await syncMeal(meal);
    }
  }

  /// Get total meal count stored in cloud.
  static Future<int> mealCount() async {
    final meals = await fetchMeals();
    return meals.length;
  }

  // ═══════════════════════════════════════════════════════════════
  // HABITS & WATER
  // ═══════════════════════════════════════════════════════════════

  /// Sync all habits + water log to the backend.
  static Future<bool> syncHabits({
    required List<Map<String, dynamic>> habitsJson,
    required Map<String, int> waterLog,
    required int waterGoal,
  }) async {
    final phone = await _getPhone();
    if (phone == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/habits/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'habits': habitsJson,
          'water_log': waterLog,
          'water_goal': waterGoal,
        }),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        SyncStatusService.instance.reportSuccess();
        return true;
      }
      SyncStatusService.instance
          .reportFailure('Habit sync (HTTP ${resp.statusCode})');
      return false;
    } catch (e) {
      debugPrint('MealSyncService.syncHabits failed: $e');
      SyncStatusService.instance.reportFailure('Habit sync failed');
      return false;
    }
  }

  /// Fetch habits + water log from cloud backup.
  /// Returns a map with 'habits', 'waterLog', 'waterGoal' keys, or null on failure.
  static Future<Map<String, dynamic>?> fetchHabits() async {
    final phone = await _getPhone();
    if (phone == null) return null;
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/habits/list/$phone'),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          // Report success only after the body parses as the expected shape,
          // so a 200-with-error-JSON never wrongly clears the banner.
          SyncStatusService.instance.reportSuccess();
          return {
            'habits': (data['habits'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            'waterLog': Map<String, int>.from(data['water_log'] as Map? ?? {}),
            'waterGoal': (data['water_goal'] as int?) ?? 8,
          };
        }
      } else {
        SyncStatusService.instance
            .reportFailure('Habit restore (HTTP ${resp.statusCode})');
      }
    } catch (e) {
      debugPrint('MealSyncService.fetchHabits failed: $e');
      SyncStatusService.instance.reportFailure('Habit restore failed');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // FULL BACKUP / RESTORE
  // ═══════════════════════════════════════════════════════════════

  /// Backup ALL data (meals + habits + water) to the cloud.
  /// Returns true if ALL syncs succeeded.
  static Future<bool> backupAll({
    required List<MealRecord> meals,
    required List<Map<String, dynamic>> habitsJson,
    required Map<String, int> waterLog,
    required int waterGoal,
  }) async {
    final phone = await _getPhone();
    if (phone == null) return false;

    bool allOk = true;

    // Backup meals
    for (final meal in meals) {
      final ok = await syncMeal(meal);
      if (!ok) allOk = false;
    }

    // Backup habits + water
    final ok = await syncHabits(
      habitsJson: habitsJson,
      waterLog: waterLog,
      waterGoal: waterGoal,
    );
    if (!ok) allOk = false;

    return allOk;
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  static Future<String?> _getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null || phone.isEmpty) return null;
    // Skip guest users
    if (phone.startsWith('guest_')) return null;
    return phone;
  }
  // NOTE: callers return early (reporting nothing) when _getPhone() is null,
  // because a guest/not-logged-in user has no cloud account — that is NOT a
  // backend failure. Widget tests rely on this: with no phone seeded in mock
  // prefs, no HTTP request is made, so no banner pops in the shell tests.
}
