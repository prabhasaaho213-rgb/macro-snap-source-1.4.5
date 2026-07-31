import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/glass_card.dart';
import 'phone_login_screen.dart';
import '../services/notification_service.dart';
import '../services/gemini_service.dart';
import '../services/razorpay_service.dart';
import '../services/subscription_service.dart';
import 'referral_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  String? _phone;
  bool _subscribed = false;
  bool _submitting = false;
  bool _checking = true;
  String? _subscribedDate;
  String? _paymentStatus;
  final _txnController = TextEditingController();
  AnimationController? _animController;
  CurvedAnimation? _checkAnim;

  @override
  void initState() {
    super.initState();
    _txnController.addListener(() => setState(() {}));
    _loadState();
  }

  @override
  void dispose() {
    RazorpayService.clearCallbacks();
    _checkAnim?.dispose();
    _animController?.stop();
    _animController?.dispose();
    _txnController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    await SubscriptionService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    final subscribed = SubscriptionService.instance.isSubscribed;
    final date = SubscriptionService.instance.subscribedAt;
    if (mounted) {
      setState(() {
        _phone = phone;
        _subscribed = subscribed;
        _subscribedDate = date;
      });
    }
    if (phone != null && !subscribed) await _checkPaymentStatus(phone);
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _checkPaymentStatus(String phone) async {
    try {
      final res = await http.get(Uri.parse('${GeminiService.serverUrl}/payment/status/$phone'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _paymentStatus = data['payment']?['status'];
            if (data['subscribed'] == true && !_subscribed) {
              _activateFromServer();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _activateFromServer() async {
    // Post-activation side effects (pro reminders + meal-store refresh) live
    // inside SubscriptionService.activate so they aren't duplicated here and
    // in RazorpayService.
    await SubscriptionService.instance.activate();
    final now = SubscriptionService.instance.subscribedAt ??
        DateTime.now().toIso8601String();
    if (mounted) {
      setState(() {
        _subscribed = true;
        _subscribedDate = now;
      });
      _showConfirmation();
    }
  }

  Future<void> _submitPayment() async {
    final txn = _txnController.text.trim();
    if (txn.isEmpty || _phone == null) return;
    setState(() { _submitting = true; _paymentStatus = null; });
    try {
      final res = await http.post(
        Uri.parse('${GeminiService.serverUrl}/payment/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phone, 'transaction_ref': txn}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() => _paymentStatus = 'pending');
          _txnController.clear();
          _showSubmitted();
          // Auto-poll for payment confirmation every 10 seconds
          _startPaymentPolling();
        }
      } else {
        if (mounted) _showError('Failed to submit. Try again.');
      }
    } catch (_) {
      if (mounted) _showError('Network error. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _polling = false;

  void _startPaymentPolling() {
    if (_polling) return;
    _polling = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted || _subscribed) return false;
      if (_phone != null) {
        await _checkPaymentStatus(_phone!);
      }
      return _paymentStatus == 'pending' && mounted;
    }).then((_) => _polling = false);
  }

  void _showSubmitted() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? MacroSnapTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                ),
                child: Icon(Icons.hourglass_top_rounded,
                    color: MacroSnapTheme.neonGreen, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Payment Submitted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              Text('Your payment is being verified.\nYou\'ll get access once confirmed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14,
                      color: MacroSnapTheme.textSecondary(context))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MacroSnapTheme.neonGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Got it',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _checkAnim?.dispose();
    _animController?.stop();
    _animController?.dispose();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnim = CurvedAnimation(parent: _animController!, curve: Curves.elasticOut);
    _animController!.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AnimatedBuilder(
          animation: _checkAnim!,
          builder: (_, _) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? MacroSnapTheme.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: _checkAnim!.value,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: MacroSnapTheme.neonGreen, size: 56),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Welcome to Pro!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 6),
                Text('Your subscription is now active',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                        color: MacroSnapTheme.textSecondary(context))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.neonGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Start Using MacroSnap',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: MacroSnapTheme.neonPink,
    ));
  }

  Future<void> _payWithRazorpay() async {
    if (_phone == null) return;
    setState(() => _submitting = true);
    try {
      RazorpayService.setErrorCallback((msg) {
        if (mounted) _showError(msg);
      });
      RazorpayService.setSuccessCallback(() {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
          _activateFromServer();
        }
      });
      await RazorpayService.startCheckout(
        phone: _phone!,
        name: 'MacroSnap User',
        email: '',
      );
    } catch (e) {
      _showError('Could not start payment: $e');
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openUpiApp() async {
    final uri = Uri.parse(
        'upi://pay?pa=7569086885@yespop&pn=MacroSnap&am=29&cu=INR&tn=MacroSnap+Pro+Subscription&mode=04');
    bool launched = false;
    try {
      // UPI deep links must launch externally; canLaunchUrl is unreliable
      // for the upi:// scheme on some devices, so attempt launch directly.
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      // Fallback: try without mode param, then show copy-to-clipboard.
      try {
        launched = await launchUrl(
          Uri.parse('upi://pay?pa=7569086885@yespop&pn=MacroSnap&am=29&cu=INR&tn=MacroSnap+Pro+Subscription'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) {
      _showError('No UPI app found. Tap the UPI ID above to copy it and pay manually.');
    }
  }

  void _startLogin() async {
    final phone = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
    if (phone != null) setState(() => _phone = phone);
  }

  String _daysRemaining() {
    if (_subscribedDate == null) return '';
    final start = DateTime.parse(_subscribedDate!);
    final expiry = start.add(const Duration(days: 30));
    final remaining = expiry.difference(DateTime.now()).inDays;
    if (remaining <= 0) return 'Expired';
    if (remaining == 1) return '1 day remaining';
    return '$remaining days remaining';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('MacroSnap Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [MacroSnapTheme.neonGreen, MacroSnapTheme.neonGreen],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: MacroSnapTheme.neonGreen.withValues(alpha:  0.3),
                        blurRadius: 20, offset: const Offset(0, 6))
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                _subscribed ? "You're a Pro!" : 'Never manually calculate macros again',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subscribed
                    ? 'Enjoy all features. ${_daysRemaining()}'
                    : 'Snap, log, track your week automatically',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w400,
                    color: MacroSnapTheme.textTertiary(context)),
              ),
              const SizedBox(height: 32),
              _buildFeatureRow(Icons.local_fire_department_rounded, 'Streak Tracking',
                  'Stay consistent with daily logging streaks', isDark),
              _buildFeatureRow(Icons.insights_rounded, 'Weekly Auto-Insights',
                  'See your protein gaps and trends without manual tracking', isDark),
              _buildFeatureRow(Icons.history_rounded, 'Complete Meal History',
                  'Review everything you ate, searchable by date', isDark),
              _buildFeatureRow(Icons.cloud_rounded, 'Cloud Backup',
                  'Your data stays safe across devices', isDark),
              _buildFeatureRow(Icons.photo_camera_rounded, 'Unlimited AI Scans',
                  'Snap any meal for instant macros â€” no limits', isDark),
              const SizedBox(height: 32),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\u20B9',
                              style: TextStyle(fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: MacroSnapTheme.neonGreen)),
                          const SizedBox(width: 2),
                          Text('29',
                              style: TextStyle(fontSize: 56,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white
                                      : MacroSnapTheme.cardDark,
                                  letterSpacing: -2, height: 1)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('/ month',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: MacroSnapTheme.textTertiary(context))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subscribed && _subscribedDate != null
                            ? 'Subscribed ${_subscribedDate!.substring(0, 10)}'
                            : 'One-time payment \u2022 Unlimited access',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MacroSnapTheme.neonGreen.withValues(alpha:  0.8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phone != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: MacroSnapTheme.neonGreen, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Logged in as $_phone',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13,
                                color: MacroSnapTheme.textSecondary(context))),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              if (!_subscribed && _checking)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!_subscribed && !_checking) ...[
                if (_phone == null) ...[
                  GradientButton(
                    label: 'Login to Subscribe',
                    onPressed: _startLogin,
                    height: 56,
                  ),
                ] else ...[
                  // Razorpay payment section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MacroSnapTheme.borderSubtle(context)),
                    ),
                    child: Column(children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.credit_card_rounded,
                                color: MacroSnapTheme.neonGreen, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pay Online (Razorpay)',
                                    style: TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white
                                            : MacroSnapTheme.cardDark)),
                                Text('UPI, Card, Netbanking, Wallet',
                                    style: TextStyle(fontSize: 13,
                                        color: MacroSnapTheme.textTertiary(context))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Pay ₹29 & Subscribe',
                        icon: Icons.lock_rounded,
                        loading: _submitting,
                        onPressed: _payWithRazorpay,
                        height: 52,
                      ),
                      const SizedBox(height: 8),
                      Text('Secure payment • Instant activation',
                          style: TextStyle(fontSize: 12,
                              color: MacroSnapTheme.textTertiary(context))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(fontSize: 12,
                                color: MacroSnapTheme.textTertiary(context))),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // UPI payment section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MacroSnapTheme.borderSubtle(context)),
                    ),
                    child: Column(children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                color: MacroSnapTheme.neonGreen, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pay via UPI',
                                    style: TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white
                                            : MacroSnapTheme.cardDark)),
                                Text('Send \u20B929 to the ID below',
                                    style: TextStyle(fontSize: 13,
                                        color: MacroSnapTheme.textTertiary(context))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              const ClipboardData(text: '7569086885@yespop'));
                          _showError('UPI ID copied!');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: MacroSnapTheme.neonGreen.withValues(alpha:  0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: MacroSnapTheme.neonGreen.withValues(alpha:  0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_rounded,
                                  color: MacroSnapTheme.neonGreen, size: 18),
                              const SizedBox(width: 8),
                              Text('7569086885@yespop',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white
                                        : MacroSnapTheme.cardDark,
                                    letterSpacing: 0.5,
                                  )),
                              const SizedBox(width: 8),
                              Icon(Icons.copy_rounded,
                                  color: MacroSnapTheme.neonGreen, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tap to copy  |  \u20B929 one-time',
                          style: TextStyle(fontSize: 12,
                              color: MacroSnapTheme.textTertiary(context))),
                      const SizedBox(height: 16),
                      GradientButton(
                        label: 'Open UPI App',
                        icon: Icons.open_in_new_rounded,
                        onPressed: _openUpiApp,
                        height: 52,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Transaction reference input
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MacroSnapTheme.borderSubtle(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_outlined,
                                color: MacroSnapTheme.neonGreen, size: 20),
                            const SizedBox(width: 8),
                            Text('Verify Payment',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white
                                        : MacroSnapTheme.cardDark)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('After paying, enter the transaction reference (UTR) here',
                            style: TextStyle(fontSize: 13,
                                color: MacroSnapTheme.textTertiary(context))),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _txnController,
                          label: 'Transaction Reference',
                          hint: 'e.g. HDFC123456789',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20,
                              color: MacroSnapTheme.textTertiary(context)),
                        ),
                        const SizedBox(height: 14),
                        GradientButton(
                          label: 'Submit for Verification',
                          loading: _submitting,
                          onPressed: _txnController.text.trim().isEmpty
                              ? null
                              : _submitPayment,
                          height: 52,
                        ),
                        if (_paymentStatus == 'pending')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: MacroSnapTheme.neonGreen),
                                ),
                                const SizedBox(width: 8),
                                Text('Awaiting confirmation...',
                                    style: TextStyle(fontSize: 13,
                                        color: MacroSnapTheme.neonGreen,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (_subscribed) ...[
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text('Subscribed \u2713',
                        style: TextStyle(
                            color: MacroSnapTheme.textSecondary(context),
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await SubscriptionService.instance.cancel();
                    await NotificationService().cancelAll();
                    setState(() {
                      _subscribed = false;
                      _subscribedDate = null;
                    });
                  },
                  child: const Text('Cancel Subscription',
                      style: TextStyle(color: MacroSnapTheme.neonPink)),
                ),
              ],
              const SizedBox(height: 16),
              Text('Cancel anytime. No questions asked.',
                  style: TextStyle(fontSize: 13,
                      color: MacroSnapTheme.textTertiary(context))),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReferralScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.neonGreen.withValues(alpha:  0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: MacroSnapTheme.neonGreen.withValues(alpha:  0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: MacroSnapTheme.neonGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Refer a Friend',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white
                                        : MacroSnapTheme.cardDark)),
                            Text('Both get Pro free for a month',
                                style: TextStyle(fontSize: 13,
                                    color: MacroSnapTheme.textTertiary(context))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: MacroSnapTheme.textTertiary(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: MacroSnapTheme.neonGreen.withValues(alpha:  0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: MacroSnapTheme.neonGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                        color: MacroSnapTheme.textTertiary(context))),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: MacroSnapTheme.neonGreen, size: 22),
        ],
      ),
    );
  }
}

