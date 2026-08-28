import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/services/meal_streak_service.dart';

/// Pins the pure streak math behind MealStreakService: continuation on
/// consecutive days, reset on a gap, and the **Zenkai Boost** — coming back
/// after breaking a 3+ day streak.
void main() {
  final today = DateTime(2026, 8, 10);
  String d(int month, int day) => '2026-$month-$day';

  group('computeStreakUpdate', () {
    test('same-day check does not change the streak', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: d(8, 10),
        current: 5,
        today: today,
      );
      expect(r.newStreak, 5);
      expect(r.brokenStreak, 0);
      expect(r.zenkai, isFalse);
    });

    test('consecutive day continues the streak', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: d(8, 9),
        current: 5,
        today: today,
      );
      expect(r.newStreak, 6);
      expect(r.zenkai, isFalse);
    });

    test('first-ever log starts a streak without a boost', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: '',
        current: 0,
        today: today,
      );
      expect(r.newStreak, 1);
      expect(r.brokenStreak, 0);
      expect(r.zenkai, isFalse);
    });

    test('short broken streak (1-2 days) is not a Zenkai Boost', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: d(8, 7),
        current: 2,
        today: today,
      );
      expect(r.newStreak, 1);
      expect(r.brokenStreak, 0);
      expect(r.zenkai, isFalse);
    });

    test('breaking a 3+ day streak and coming back triggers Zenkai Boost', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: d(8, 7),
        current: 12,
        today: today,
      );
      expect(r.newStreak, 1);
      expect(r.brokenStreak, 12);
      expect(r.zenkai, isTrue);
    });

    test('a two-day gap after a long streak is still a Zenkai Boost', () {
      final r = MealStreakService.computeStreakUpdate(
        lastDate: d(8, 5),
        current: 30,
        today: today,
      );
      expect(r.newStreak, 1);
      expect(r.brokenStreak, 30);
      expect(r.zenkai, isTrue);
    });
  });
}
