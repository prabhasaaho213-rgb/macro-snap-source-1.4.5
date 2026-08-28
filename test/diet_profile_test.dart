import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/models/diet_profile.dart';

void main() {
  test('falls back to safe defaults for invalid persisted enum values', () {
    final profile = DietProfile.fromJson({
      'weightKg': 70,
      'heightCm': 175,
      'age': 28,
      'gender': 'unknown',
      'goal': 'unknown',
      'activity': 'unknown',
      'avatar': '😎',
    });

    expect(profile.gender, Gender.male);
    expect(profile.goal, Goal.loseWeight);
    expect(profile.activity, ActivityLevel.sedentary);
  });
}
