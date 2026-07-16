import 'package:share_plus/share_plus.dart' show Share;
import '../services/meal_store.dart';

class ShareService {
  static String _weekSummary() {
    final meals = MealStore.instance.allMeals;
    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 6);

    final weekMeals = meals.where((m) =>
      m.date.isAfter(sevenDaysAgo.subtract(const Duration(days: 1))) &&
      m.date.isBefore(now.add(const Duration(days: 1)))
    ).toList();

    if (weekMeals.isEmpty) return '';

    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFats = 0;
    final daysLogged = <String>{};

    for (final m in weekMeals) {
      totalCal += m.calories;
      totalProtein += m.protein;
      totalCarbs += m.carbs;
      totalFats += m.fats;
      daysLogged.add('${m.date.year}-${m.date.month}-${m.date.day}');
    }

    final avgProtein = weekMeals.isNotEmpty ? (totalProtein / weekMeals.length) : 0.0;

    return '''📊 MacroSnap Weekly Summary
━━━━━━━━━━━━━━━━━━
📅 ${daysLogged.length}/7 days logged
${daysLogged.length >= 6 ? '⭐ Great consistency!' : daysLogged.length >= 4 ? '👍 Good effort!' : '💪 Keep going!'}

🔥 Total: ${totalCal.toStringAsFixed(0)} kcal
💪 Protein: ${totalProtein.toStringAsFixed(0)}g (avg ${avgProtein.toStringAsFixed(1)}g/day)
🌾 Carbs: ${totalCarbs.toStringAsFixed(0)}g
🥑 Fats: ${totalFats.toStringAsFixed(0)}g
━━━━━━━━━━━━━━━━━━
Track every meal with MacroSnap 🍽️''';
  }

  static Future<void> shareWeekSummary() async {
    final text = _weekSummary();
    if (text.isEmpty) {
      throw Exception('No meals logged this week to share.');
    }
    await Share.share(text);
  }
}