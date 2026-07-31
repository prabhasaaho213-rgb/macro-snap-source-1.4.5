import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meal_store.dart';
import 'notification_service.dart';

/// Central reactive store for the Pro subscription flag.
///
/// Replaces ad-hoc `prefs.getBool('subscribed')` reads scattered across
/// screens and services. Screens read [isSubscribed] / [subscribedAt] and can
/// listen for changes so an activation (Razorpay, UPI verification, server
/// poll) or cancellation immediately updates every open screen.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String _subscribedKey = 'subscribed';
  static const String _subscribedAtKey = 'subscribed_at';

  bool _subscribed = false;
  String? _subscribedAt;

  bool get isSubscribed => _subscribed;
  String? get subscribedAt => _subscribedAt;

  /// Loads the persisted flag. Called once at app startup, but safe to call
  /// again — re-reads prefs and only notifies when the value changed.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final subscribed = p.getBool(_subscribedKey) ?? false;
    final at = p.getString(_subscribedAtKey);
    if (subscribed != _subscribed || at != _subscribedAt) {
      _subscribed = subscribed;
      _subscribedAt = at;
      notifyListeners();
    }
  }

  /// Activates Pro: persists the flag + timestamp, runs the post-activation
  /// side effects (pro reminder notifications + refresh of the meal-store
  /// change notifier so scan counts update), and notifies listeners.
  ///
  /// Centralizing the side effects here removes the duplication that used to
  /// live in both [RazorpayService] and the subscription screen.
  Future<void> activate() async {
    final now = DateTime.now().toIso8601String();
    final p = await SharedPreferences.getInstance();
    await p.setString(_subscribedAtKey, now);
    await p.setBool(_subscribedKey, true);
    _subscribed = true;
    _subscribedAt = now;
    notifyListeners();

    // ── Post-activation side effects (best-effort, never throw) ──
    // Schedule daily pro reminder notifications.
    try {
      await NotificationService().scheduleAllForSubscriber(
          _subscribedAt ?? now);
    } catch (_) {}
    // Bump the meal-store notifier so home/scan screens refresh scan counts.
    try {
      MealStore.instance.changeNotifier.value++;
    } catch (_) {}
  }

  /// Cancels the subscription: clears the flag + timestamp and notifies.
  Future<void> cancel() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_subscribedKey, false);
    await p.remove(_subscribedAtKey);
    _subscribed = false;
    _subscribedAt = null;
    notifyListeners();
  }
}
