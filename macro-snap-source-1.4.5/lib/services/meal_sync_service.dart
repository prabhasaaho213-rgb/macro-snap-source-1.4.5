import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_record.dart';
import 'gemini_service.dart';

/// Handles cloud backup/sync of meal data to the backend server.
/// Uses the user's 500MB backend database for storage.
class MealSyncService {
  static String get _baseUrl => GeminiService.serverUrl;

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
      return resp.statusCode == 200;
    } catch (_) {
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
      return resp.statusCode == 200;
    } catch (_) {
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
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => MealRecord.fromJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Bulk sync all local meals to the backend.
  static Future<void> syncAll(List<MealRecord> meals) async {
    for (final meal in meals) {
      await syncMeal(meal);
    }
  }

  static Future<String?> _getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (phone == null || phone.isEmpty) return null;
    // Skip guest users
    if (phone.startsWith('guest_')) return null;
    return phone;
  }
}
