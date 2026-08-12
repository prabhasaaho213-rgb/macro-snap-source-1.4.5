import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_identity.dart';
import 'meal_store.dart';
import 'gemini_service.dart';
import 'sync_status_service.dart';

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
    // Refresh scan counts. Reminder scheduling is NOT here —
    // NotificationService listens to this notifier and applies the plan on
    // every state change, so a cold start can't be held up while the
    // notification plugin schedules reminders.
    try {
      MealStore.instance.changeNotifier.value++;
    } catch (_) {}
  }

  /// Verifies the paid subscription from **Firestore** — the source of truth
  /// for payments and subscription state after the Phase-3 migration.
  ///
  /// Reads `users/{uid}.subscribed` (written by the backend's Razorpay
  /// webhook/verify via the Admin SDK). Falls back to the legacy
  /// `/subscription/status` backend call when Firestore has no user doc yet
  /// (Phase-1/2 backfill not caught up) or when Firestore is unreachable.
  ///
  /// Called at app startup and after sign-in so a paying user who reinstalls
  /// or switches devices gets Pro restored without opening the subscription
  /// screen. Never deactivates locally — transient network failures must not
  /// strip a user's paid status.
  Future<void> verifyServerSubscription() async {
    // The admin's lifetime Pro is local-only; don't override it.
    if (await isAdmin()) return;

    // ── Firestore first: users/{uid}.subscribed ────────────────────────
    try {
      final uid = await FirebaseIdentity.currentUid();
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists) {
          final subscribed = doc.data()?['subscribed'] == true;
          if (subscribed && !_subscribed) {
            // Activation from Firestore is authoritative.
            await activate();
            return;
          }
          // `subscribed == false` is NOT authoritative during the migration
          // window (a Firestore doc can be stale while Postgres says paid) —
          // fall through to the backend check below to confirm.
        }
      }
    } catch (_) {
      // Firestore unavailable — fall through to the backend check.
    }

    // ── Backend fallback: Postgres /subscription/status ─────────────────
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
      // Offline or server unreachable — keep the local state as-is, but
      // surface the dead backend so the user isn't silently cut off from
      // cloud features (same signal the meal/habit sync uses).
      SyncStatusService.instance.reportFailure('Subscription check failed');
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

    // ── Post-activation side effect (best-effort, never throw) ──
    // Refresh scan counts. Reminder scheduling is NOT here —
    // NotificationService listens to this notifier and applies the plan on
    // every state change.
    try {
      MealStore.instance.changeNotifier.value++;
    } catch (_) {}
  }

  /// Cancels the subscription: stops the recurring Razorpay charge on the
  /// server, clears the flag + timestamp and notifies.
  ///
  /// The server call is fire-and-forget — the local downgrade is instant and
  /// never blocked by the network (offline cancel still works, and the
  /// recurring charge stop is retried on the next cancel / handled by the
  /// subscription.cancelled webhook).
  Future<void> cancel() async {
    unawaited(_notifyServerCancellation());
    final p = await SharedPreferences.getInstance();
    await p.setBool(_subscribedKey, false);
    await p.remove(_subscribedAtKey);
    _subscribed = false;
    _subscribedAt = null;
    notifyListeners();
  }

  /// Best-effort: tell the backend to cancel the Razorpay recurring plan so
  /// future monthly auto-charges stop. Never throws — a failure only logs;
  /// the local downgrade has already happened.
  Future<void> _notifyServerCancellation() async {
    try {
      final p = await SharedPreferences.getInstance();
      final phone = p.getString('phone');
      if (phone == null || phone.isEmpty) return;
      await http
          .post(
            Uri.parse('${GeminiService.serverUrl}/payment/cancel-subscription'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('❌ cancel-subscription call failed: $e');
    }
  }
}
