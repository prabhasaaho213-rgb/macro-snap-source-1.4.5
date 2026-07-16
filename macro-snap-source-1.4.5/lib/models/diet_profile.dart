import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum Goal { loseWeight, maintain, gainMuscle }
enum ActivityLevel { sedentary, light, moderate, active, veryActive }
enum Gender { male, female }

class DietProfile {
  final double weightKg;
  final double heightCm;
  final int age;
  final Gender gender;
  final Goal goal;
  final ActivityLevel activity;
  final String avatar;

  DietProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    required this.goal,
    required this.activity,
    this.avatar = '😎',
  });

  static const List<String> avatars = [
    '😎', '🥳', '🤠', '🤓',
    '🧐', '😇', '🤩', '😋',
    '🤪', '🦊', '🐼', '🐱',
  ];

  double get bmr {
    if (gender == Gender.male) {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  double get tdee {
    final multipliers = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.active: 1.725,
      ActivityLevel.veryActive: 1.9,
    };
    return bmr * (multipliers[activity] ?? 1.2);
  }

  int get targetCalories {
    switch (goal) {
      case Goal.loseWeight:
        return (tdee - 500).round();
      case Goal.maintain:
        return tdee.round();
      case Goal.gainMuscle:
        return (tdee + 300).round();
    }
  }

  double get targetProtein {
    switch (goal) {
      case Goal.loseWeight:
        return (weightKg * 2.0);
      case Goal.maintain:
        return (weightKg * 1.6);
      case Goal.gainMuscle:
        return (weightKg * 2.2);
    }
  }

  double get targetFats => (targetCalories * 0.25 / 9);
  double get targetCarbs => (targetCalories - (targetProtein * 4) - (targetFats * 9)) / 4;

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'gender': gender.name,
    'goal': goal.name,
    'activity': activity.name,
    'avatar': avatar,
  };

  factory DietProfile.fromJson(Map<String, dynamic> json) {
    final genderName = json['gender'] as String?;
    final goalName = json['goal'] as String?;
    final activityName = json['activity'] as String?;

    return DietProfile(
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
      age: (json['age'] as num?)?.toInt() ?? 28,
      gender: Gender.values.firstWhere(
        (g) => g.name == genderName,
        orElse: () => Gender.male,
      ),
      goal: Goal.values.firstWhere(
        (g) => g.name == goalName,
        orElse: () => Goal.loseWeight,
      ),
      activity: ActivityLevel.values.firstWhere(
        (a) => a.name == activityName,
        orElse: () => ActivityLevel.sedentary,
      ),
      avatar: json['avatar'] as String? ?? '😎',
    );
  }
}

class DietPlanService {
  static final DietPlanService _instance = DietPlanService._();
  static DietPlanService get instance => _instance;
  DietPlanService._();

  DietProfile? _profile;
  DietProfile? get profile => _profile;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/diet_profile.json');
      if (await file.exists()) {
        _profile = DietProfile.fromJson(jsonDecode(await file.readAsString()));
      }
    } catch (_) {}
  }

  Future<void> save(DietProfile profile) async {
    _profile = profile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/diet_profile.json');
      await file.writeAsString(jsonEncode(profile.toJson()));
    } catch (_) {}
  }

  static String goalLabel(Goal g) {
    switch (g) {
      case Goal.loseWeight: return 'Weight Loss';
      case Goal.maintain: return 'Maintain';
      case Goal.gainMuscle: return 'Muscle Gain';
    }
  }

  static String activityLabel(ActivityLevel a) {
    switch (a) {
      case ActivityLevel.sedentary: return 'Sedentary (desk job)';
      case ActivityLevel.light: return 'Light (1-2 days/week)';
      case ActivityLevel.moderate: return 'Moderate (3-5 days/week)';
      case ActivityLevel.active: return 'Active (6-7 days/week)';
      case ActivityLevel.veryActive: return 'Very Active (twice/day)';
    }
  }
}
