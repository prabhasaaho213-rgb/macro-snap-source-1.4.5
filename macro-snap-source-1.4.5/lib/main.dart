import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/meal_store.dart';
import 'models/diet_profile.dart';
import 'services/notification_service.dart';
import 'services/gemini_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await GeminiService.init();
  await NotificationService().init();
  // Schedule daily reminders for ALL users (free + pro)
  try {
    NotificationService().scheduleDailyReminder();
    NotificationService().scheduleStreakReminder();
  } catch (_) {}
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await MealStore.instance.load();
  await DietPlanService.instance.load();
  runApp(const MacroSnapApp());
}
