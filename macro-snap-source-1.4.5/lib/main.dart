import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kReleaseMode;
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

Future<void> main() async {
  // ── Global crash safety net ────────────────────────────────────────
  // Last line of defense behind the guarded startup steps: any framework
  // error and any uncaught platform/zone error is logged and swallowed
  // instead of terminating the isolate. Previously an unhandled error at
  // launch left the app stuck on a black screen, unable to open.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter framework error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Uncaught platform error: $error');
    // Swallow in release (the app must never die for users) but rethrow in
    // debug so developers still see uncaught errors loudly during dev.
    return kReleaseMode;
  };
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Failure-tolerant startup ────────────────────────────────
      // Every step below is guarded so a corrupted local file, an
      // unreachable backend, or a plugin failure can NEVER leave the user
      // stuck on a black splash screen. If something fails we log it and
      // keep going — the app must always open.
      try {
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized successfully');
      } catch (e) {
        debugPrint('❌ Firebase initialization FAILED: $e');
        // App continues but Firebase features (auth, etc.) will not work
      }
      await _guard(() => GeminiService.init(), 'GeminiService.init');
      try {
        RazorpayService.init();
      } catch (e) {
        debugPrint('❌ RazorpayService.init failed: $e');
      }
      await _guard(
        () => SubscriptionService.instance.load(),
        'SubscriptionService.load',
      );
      // Verify the paid subscription against the backend Postgres database —
      // the source of truth — so paying users get Pro restored on
      // reinstall/device change even before opening the subscription screen.
      // (Fire-and-forget.)
      unawaited(SubscriptionService.instance.verifyServerSubscription());
      await _guard(
        () => NotificationService().init(),
        'NotificationService.init',
      );
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Local data loads fast; cloud restore merges in the background so a
      // slow or sleeping backend never delays the first frame.
      await _guard(() => MealStore.instance.load(), 'MealStore.load');
      await _guard(
        () => DietPlanService.instance.load(),
        'DietPlanService.load',
      );
      await _guard(() => HabitStore.instance.load(), 'HabitStore.load');
      // Restore ALL reminders every launch — the OS drops scheduled alarms
      // on reinstall/update/force-stop, and without this, reminders
      // silently stop working. (Fire-and-forget, error-guarded.)
      unawaited(
        _guard(() async {
          await NotificationService().restoreAllReminders(
            HabitStore.instance.habits,
            subscribedDate: SubscriptionService.instance.subscribedAt,
          );
        }, 'NotificationService reminders'),
      );

      runApp(const MacroSnapApp());
    },
    (error, stack) {
      debugPrint('❌ Uncaught zone error: $error\n$stack');
    },
  );
}

/// Runs a single startup step, swallowing any error so one failure can
/// never block [runApp]. Returns normally even when [fn] throws.
Future<void> _guard(Future<void> Function() fn, String label) async {
  try {
    await fn();
  } catch (e) {
    debugPrint('❌ $label failed: $e');
  }
}
