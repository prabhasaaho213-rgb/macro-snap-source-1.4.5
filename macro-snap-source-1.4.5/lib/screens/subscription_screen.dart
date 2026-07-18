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
  Animation<double>? _checkAnim;

  @override
  void initState() {
    super.initState();
    _txnController.addListener(() => setState(() {}));
    _loadState();
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _txnController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    final subscribed = prefs.getBool('subscribed') ?? false;
    final date = prefs.getString('subscribed_at');
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
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('subscribed_at', now);
    await prefs.setBool('subscribed', true);
    // Schedule notifications for pro subscribers
    try {
      await NotificationService().scheduleAllForSubscriber(now);
    } catch (_) {}
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

  void _showSubmitted() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MacroSnapTheme.emerald.withOpacity( 0.1),
                ),
                child: Icon(Icons.hourglass_top_rounded,
                    color: MacroSnapTheme.emerald, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Payment Submitted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('Your payment is being verified.\nYou\'ll get access once confirmed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MacroSnapTheme.emerald,
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
                ? const Color(0xFF1E293B) : Colors.white,
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
                      color: MacroSnapTheme.emerald.withOpacity( 0.1),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: MacroSnapTheme.emerald, size: 56),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Welcome to Pro!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Text('Your subscription is now active',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.emerald,
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
      backgroundColor: MacroSnapTheme.rose,
    ));
  }

  void _openUpiApp() async {
    final uri = Uri.parse('upi://pay?pa=7569086885@yespop&pn=MacroSnap&am=29&cu=INR&tn=MacroSnap+Pro+Subscription');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('No UPI app found. Copy the UPI ID and pay manually.');
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
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
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
                    colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: MacroSnapTheme.emerald.withOpacity( 0.3),
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
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
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
                                  color: MacroSnapTheme.emerald)),
                          const SizedBox(width: 2),
                          Text('29',
                              style: TextStyle(fontSize: 56,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white
                                      : const Color(0xFF1E293B),
                                  letterSpacing: -2, height: 1)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('/ month',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38
                                        : const Color(0xFF94A3B8))),
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
                            color: MacroSnapTheme.emerald.withOpacity( 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phone != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        color: MacroSnapTheme.emerald, size: 16),
                    const SizedBox(width: 6),
                    Text('Logged in as $_phone',
                        style: TextStyle(fontSize: 13,
                            color: isDark ? Colors.white60
                                : const Color(0xFF64748B))),
                  ],
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
                  // UPI payment section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: MacroSnapTheme.emerald.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                color: MacroSnapTheme.emerald, size: 22),
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
                                            : const Color(0xFF1E293B))),
                                Text('Send \u20B929 to the ID below',
                                    style: TextStyle(fontSize: 13,
                                        color: isDark ? Colors.white38
                                            : const Color(0xFF94A3B8))),
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
                            color: MacroSnapTheme.emerald.withOpacity( 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: MacroSnapTheme.emerald.withOpacity( 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_rounded,
                                  color: MacroSnapTheme.emerald, size: 18),
                              const SizedBox(width: 8),
                              Text('7569086885@yespop',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white
                                        : const Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  )),
                              const SizedBox(width: 8),
                              Icon(Icons.copy_rounded,
                                  color: MacroSnapTheme.emerald, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tap to copy  |  \u20B929 one-time',
                          style: TextStyle(fontSize: 12,
                              color: isDark ? Colors.white30
                                  : const Color(0xFF94A3B8))),
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
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_outlined,
                                color: MacroSnapTheme.emerald, size: 20),
                            const SizedBox(width: 8),
                            Text('Verify Payment',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white
                                        : const Color(0xFF1E293B))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('After paying, enter the transaction reference (UTR) here',
                            style: TextStyle(fontSize: 13,
                                color: isDark ? Colors.white38
                                    : const Color(0xFF94A3B8))),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _txnController,
                          label: 'Transaction Reference',
                          hint: 'e.g. HDFC123456789',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20,
                              color: isDark ? Colors.white38
                                  : const Color(0xFF94A3B8)),
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
                                      color: MacroSnapTheme.emerald),
                                ),
                                const SizedBox(width: 8),
                                Text('Awaiting confirmation...',
                                    style: TextStyle(fontSize: 13,
                                        color: MacroSnapTheme.emerald,
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
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('subscribed', false);
                    await prefs.remove('subscribed_at');
                    await NotificationService().cancelAll();
                    setState(() {
                      _subscribed = false;
                      _subscribedDate = null;
                    });
                  },
                  child: const Text('Cancel Subscription',
                      style: TextStyle(color: MacroSnapTheme.rose)),
                ),
              ],
              const SizedBox(height: 16),
              Text('Cancel anytime. No questions asked.',
                  style: TextStyle(fontSize: 13,
                      color: isDark ? Colors.white30
                          : const Color(0xFFCBD5E1))),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReferralScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MacroSnapTheme.emerald.withOpacity( 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: MacroSnapTheme.emerald.withOpacity( 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: MacroSnapTheme.emerald.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: MacroSnapTheme.emerald, size: 22),
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
                                        : const Color(0xFF1E293B))),
                            Text('Both get Pro free for a month',
                                style: TextStyle(fontSize: 13,
                                    color: isDark ? Colors.white38
                                        : const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
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
                color: MacroSnapTheme.emerald.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: MacroSnapTheme.emerald, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B))),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: MacroSnapTheme.emerald, size: 22),
        ],
      ),
    );
  }
}

