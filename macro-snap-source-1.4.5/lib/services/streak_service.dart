import 'package:shared_preferences/shared_preferences.dart';
import 'package:macro_snap/services/meal_store.dart';

class StreakService {
  static const _keyStreak = 'current_streak';
  static const _keyBest = 'best_streak';
  static const _keyDate = 'last_streak_date';

  static Future<int> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStreak) ?? 0;
  }

  static Future<int> getBest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBest) ?? 0;
  }

  static Future<void> checkAndUpdate() async {
    final meals = MealStore.instance.todayMeals;
    if (meals.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastDate = prefs.getString(_keyDate) ?? '';
    final current = prefs.getInt(_keyStreak) ?? 0;

    if (lastDate == todayStr) return;

    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    int newStreak;
    if (lastDate == yesterdayStr) {
      newStreak = current + 1;
    } else {
      newStreak = 1;
    }

    await prefs.setInt(_keyStreak, newStreak);
    await prefs.setString(_keyDate, todayStr);

    final best = prefs.getInt(_keyBest) ?? 0;
    if (newStreak > best) {
      await prefs.setInt(_keyBest, newStreak);
    }
  }

  static bool isLongestStreak(int current, int best) {
    return current >= best && current > 0;
  }
}
