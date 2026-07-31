import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/meal_store.dart';
import 'models/diet_profile.dart';
import 'services/notification_service.dart';
import 'services/gemini_service.dart';
import 'services/razorpay_service.dart';
import 'services/habit_store.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization FAILED: $e');
    // App continues but Firebase features (auth, etc.) will not work
  }
  await GeminiService.init();
  RazorpayService.init();
  await SubscriptionService.instance.load();
  // Verify the paid subscription against the backend Postgres database — the
  // source of truth — so paying users get Pro restored on reinstall/device
  // change even before opening the subscription screen.
  unawaited(SubscriptionService.instance.verifyServerSubscription());
  await NotificationService().init();
  // Schedule daily reminders for ALL users (free + pro)
  try {
    NotificationService().scheduleDailyReminder();
    NotificationService().scheduleStreakReminder();
  } catch (_) {}
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await MealStore.instance.load();
  await DietPlanService.instance.load();
  await HabitStore.instance.load();
  runApp(const MacroSnapApp());
}
