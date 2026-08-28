import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/models/meal_record.dart';
import 'package:macro_snap/services/meal_sync_service.dart';

/// Unit tests for [MealSyncService.mealFromMap] — the migration-critical
/// conversion that turns a Firestore `meals/{id}` doc into a [MealRecord].
///
/// Two doc shapes must both read cleanly:
///   1. App-written (Phase 3+): ISO-string `date`, explicit `id` field.
///   2. Backend/backfill-written (Phase 1/2): Firestore [Timestamp] `date`,
///      NO `id` field, and nullable optional strings.
void main() {
  group('mealFromMap — app-written doc shape', () {
    test('ISO-string date with explicit id round-trips unchanged', () {
      final meal = MealSyncService.mealFromMap({
        'id': 'meal-abc',
        'date': '2026-08-04T09:30:00.000',
        'name': 'Idli',
        'category': 'Breakfast',
        'calories': 200,
        'protein': 5.0,
        'carbs': 35.0,
        'fats': 2.0,
        'fiber': 3.0,
        'serving': '2 pieces',
        'uid': 'user-123',
      }, 'meal-abc');

      expect(meal.id, 'meal-abc');
      expect(meal.name, 'Idli');
      expect(meal.category, 'Breakfast');
      expect(meal.calories, 200);
      expect(meal.protein, 5.0);
      expect(meal.date, DateTime.parse('2026-08-04T09:30:00.000'));
    });
  });

  group('mealFromMap — backend/backfill-written doc shape', () {
    test('Timestamp date and no id field uses the doc id', () {
      final meal = MealSyncService.mealFromMap({
        'date': Timestamp.fromDate(DateTime(2026, 8, 4, 9, 30)),
        'name': 'Dal Rice',
        'category': 'Lunch',
        'calories': 450,
        'protein': 14,
        'carbs': 60,
        'fats': 8,
        'fiber': 6,
        'serving': '1 plate',
        'uid': 'user-123',
      }, 'doc-from-backfill-1');

      expect(meal.id, 'doc-from-backfill-1');
      expect(meal.date, DateTime(2026, 8, 4, 9, 30));
      expect(meal.name, 'Dal Rice');
    });

    test('null optional strings default to empty', () {
      final meal = MealSyncService.mealFromMap({
        'date': Timestamp.fromDate(DateTime(2026, 8, 4)),
        'name': 'Roti',
        'calories': 120,
        'protein': 3,
        'carbs': 20,
        'fats': 1,
        'fiber': 2,
        'category': null,
        'serving': null,
        'uid': 'user-123',
      }, 'doc-2');

      expect(meal.category, '');
      expect(meal.serving, '');
    });
  });

  group('mealFromMap — edge cases', () {
    test('DateTime (non-Timestamp) date is normalized too', () {
      final meal = MealSyncService.mealFromMap({
        'date': DateTime(2026, 8, 4, 18, 45),
        'name': 'Curd Rice',
        'calories': 300,
        'protein': 8,
        'carbs': 45,
        'fats': 5,
        'fiber': 2,
      }, 'doc-3');

      expect(meal.date, DateTime(2026, 8, 4, 18, 45));
      expect(meal.id, 'doc-3');
    });

    test('integer macro values are coerced to double', () {
      final meal = MealSyncService.mealFromMap({
        'date': '2026-08-04T08:00:00.000',
        'name': 'Banana',
        'calories': 105,
        'protein': 1,
        'carbs': 27,
        'fats': 0,
        'fiber': 3,
      }, 'doc-4');

      expect(meal.protein, 1.0);
      expect(meal.carbs, 27.0);
      expect(meal.fats, 0.0);
      expect(meal.fiber, 3.0);
    });
  });
}
