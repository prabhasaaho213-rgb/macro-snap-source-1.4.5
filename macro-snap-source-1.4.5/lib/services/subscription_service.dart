import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'meal_store.dart';
import 'notification_service.dart';
import 'gemini_service.dart';

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

  /// The owner account — always gets Pro for free, forever.
  static const String adminEmail = 'prabhasaaho213@gmail.com';

  bool _subscribed = false;
  String? _subscribedAt;

  bool get isSubscribed => _subscribed;
  String? get subscribedAt => _subscribedAt;

  /// True when the currently signed-in email is the owner/admin account.
  /// The admin gets a permanent, free Pro subscription.
  Future<bool> isAdmin() async {
    final p = await SharedPreferences.getInstance();
    final email = (p.getString('email') ?? '').trim().toLowerCase();
    return email == adminEmail.toLowerCase();
  }

  /// Loads the persisted flag. Called once at app startup, but safe to call
  /// again — re-reads prefs and only notifies when the value changed.
  ///
  /// Admin override: the owner's email always yields Pro for free, forever.
  /// Non-admin guard: a persisted lifetime grant (the `1900` marker) must
  /// never transfer to another user who signs in on the same device, so it is
  /// cleared when the current user isn't the admin.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    var subscribed = p.getBool(_subscribedKey) ?? false;
    var at = p.getString(_subscribedAtKey);

    if (await isAdmin()) {
      // Owner: force lifetime Pro, regardless of any previous paid state.
      if (at != _lifetimeDate) {
        await _grantLifetimeAdmin();
      }
      subscribed = true;
      at = _lifetimeDate;
    } else if (at == _lifetimeDate) {
      // A non-owner signed in on a device where the owner granted lifetime
      // Pro — strip the grant so it doesn't leak to them.
      await p.remove(_subscribedAtKey);
      await p.setBool(_subscribedKey, false);
      subscribed = false;
      at = null;
    }

    if (subscribed != _subscribed || at != _subscribedAt) {
      _subscribed = subscribed;
      _subscribedAt = at;
      notifyListeners();
    }
  }

  /// Marker timestamp shown for the admin's lifetime subscription.
  static final String _lifetimeDate = '1900-01-01T00:00:00.000';

  Future<void> _grantLifetimeAdmin() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_subscribedKey, true);
    await p.setString(_subscribedAtKey, _lifetimeDate);
    _subscribed = true;
    _subscribedAt = _lifetimeDate;
    notifyListeners();
    // Post-activation side effects (pro reminders) — best-effort.
    try {
      await NotificationService().scheduleAllForSubscriber(_lifetimeDate);
    } catch (_) {}
    try {
      MealStore.instance.changeNotifier.value++;
    } catch (_) {}
  }

  /// Verifies the subscription against the backend PostgreSQL database — the
  /// source of truth for payments and subscription state.
  ///
  /// Called at app startup and after sign-in so a paying user who reinstalls
  /// or switches devices gets Pro restored from the database without needing
  /// to open the subscription screen. Never deactivates locally — transient
  /// network failures must not strip a user's paid status.
  Future<void> verifyServerSubscription() async {
    // The admin's lifetime Pro is local-only; don't override it.
    if (await isAdmin()) return;
    final p = await SharedPreferences.getInstance();
    final email = p.getString('email');
    final phone = p.getString('phone');
    if ((email == null || email.isEmpty) &&
        (phone == null || phone.isEmpty)) {
      return; // Guest — nothing to verify.
    }
    try {
      final uri = Uri.parse('${GeminiService.serverUrl}/subscription/status')
          .replace(queryParameters: {
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (email != null && email.isNotEmpty) 'email': email,
          });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['subscribed'] == true && !_subscribed) {
        await activate();
      }
    } catch (_) {
      // Offline or server unreachable — keep the local state as-is.
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
