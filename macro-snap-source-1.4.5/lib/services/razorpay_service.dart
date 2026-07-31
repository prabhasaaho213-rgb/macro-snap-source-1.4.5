import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';
import 'subscription_service.dart';

class RazorpayService {
  static final Razorpay _razorpay = Razorpay();
  static bool _initialized = false;
  static String? _lastOrderId;

  /// Initialize Razorpay. Call this once in the app lifecycle.
  static void init() {
    if (_initialized) return;
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initialized = true;
  }

  /// Clean up listeners when no longer needed.
  static void dispose() {
    if (!_initialized) return;
    _razorpay.clear();
    _initialized = false;
  }

  /// Start the Razorpay checkout flow for a ₹29 subscription.
  static Future<void> startCheckout({
    required String phone,
    required String name,
    required String email,
  }) async {
    try {
      // 1. Create order on backend
      final orderResponse = await http.post(
        Uri.parse('${GeminiService.serverUrl}/payment/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'amount': 2900, // ₹29 in paise
          'currency': 'INR',
        }),
      );

      if (orderResponse.statusCode != 200) {
        throw Exception('Failed to create payment order');
      }

      final orderData = jsonDecode(orderResponse.body);
      _lastOrderId = orderData['order_id'] as String;
      final razorpayKey = orderData['razorpay_key'] as String;

      // Get stored user info for receipt
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('name') ?? name;
      final userEmail = prefs.getString('email') ?? email;

      // 2. Open Razorpay checkout
      final options = {
        'key': razorpayKey,
        'amount': 2900,
        'currency': 'INR',
        'name': 'MacroSnap',
        'description': 'Pro Subscription (₹29)',
        'order_id': _lastOrderId,
        'prefill': {
          'contact': phone,
          'name': userName,
          'email': userEmail,
        },
        'theme': {
          'color': '#10B981', // Emerald green matching MacroSnap theme
        },
      };

      _razorpay.open(options);
    } catch (e) {
      _lastOrderId = null;
      rethrow;
    }
  }

  /// Handle successful payment from Razorpay.
  static void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Verify payment on backend
      final verifyResponse = await http.post(
        Uri.parse('${GeminiService.serverUrl}/payment/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );

      if (verifyResponse.statusCode == 200) {
        // Payment verified — activate subscription
        await _activateSubscription();
        // Notify the UI that payment succeeded
        if (_onSuccessCallback != null) {
          _onSuccessCallback!();
        }
      } else {
        _showError('Payment verification failed. Please contact support.');
      }
    } catch (e) {
      _showError('Verification error. Your payment may still be processed.');
    }
  }

  /// Handle payment failure.
  static void _handlePaymentError(PaymentFailureResponse response) {
    _lastOrderId = null;
    String message = 'Payment cancelled';
    if (response.code != 0) {
      message = 'Payment failed: ${response.message ?? "Please try again"}';
    }
    _showError(message);
  }

  /// Handle external wallet selection.
  static void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('${response.walletName} selected. Please complete the payment.');
  }

  /// Activate the subscription after successful payment verification.
  ///
  /// Post-activation side effects (pro reminders + meal-store refresh) live
  /// inside [SubscriptionService.activate] so they aren't duplicated here and
  /// in the subscription screen.
  static Future<void> _activateSubscription() async {
    await SubscriptionService.instance.activate();
    _lastOrderId = null;
  }

  /// Show a snackbar error message (uses a global key approach).
  static void _showError(String message) {
    if (_onErrorCallback != null) {
      _onErrorCallback!(message);
    }
  }

  static void Function(String)? _onErrorCallback;
  static VoidCallback? _onSuccessCallback;

  /// Set a callback for showing error messages from the UI.
  static void setErrorCallback(void Function(String) callback) {
    _onErrorCallback = callback;
  }

  /// Set a callback for when payment succeeds and is verified.
  static void setSuccessCallback(VoidCallback callback) {
    _onSuccessCallback = callback;
  }

  /// Clear all callbacks.
  static void clearCallbacks() {
    _onErrorCallback = null;
    _onSuccessCallback = null;
  }
}
