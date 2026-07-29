import 'package:shared_preferences/shared_preferences.dart';
import 'package:macro_snap/services/meal_store.dart';
import 'package:macro_snap/models/diet_profile.dart';

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

  /// Check if today's macro targets have been met (all 3 macros >= 90% target)
  static bool _allMacrosHit() {
    final profile = DietPlanService.instance.profile;
    final p = MealStore.instance.todayProtein;
    final c = MealStore.instance.todayCarbs;
    final f = MealStore.instance.todayFats;
    final targetP = profile?.targetProtein ?? 150;
    final targetC = profile?.targetCarbs ?? 300;
    final targetF = profile?.targetFats ?? 67;
    return p >= targetP * 0.9 && c >= targetC * 0.9 && f >= targetF * 0.9;
  }

  static Future<void> checkAndUpdate() async {
    // Streak = consecutive days where ALL macro targets are hit (>= 90% each)
    if (!_allMacrosHit()) return;

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

  /// Check if ALL macro targets are hit today (>= 90% of each target)
  static bool checkAllTargetsHit() {
    final profile = DietPlanService.instance.profile;
    final p = MealStore.instance.todayProtein;
    final c = MealStore.instance.todayCarbs;
    final f = MealStore.instance.todayFats;
    final targetP = profile?.targetProtein ?? 150;
    final targetC = profile?.targetCarbs ?? 300;
    final targetF = profile?.targetFats ?? 67;
    return p >= targetP * 0.9 && c >= targetC * 0.9 && f >= targetF * 0.9;
  }
}
