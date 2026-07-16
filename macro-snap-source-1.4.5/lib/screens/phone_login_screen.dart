import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/app_text_field.dart';
import 'home_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String? returnRoute;
  const PhoneLoginScreen({super.key, this.returnRoute});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController(text: '+91');
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _googleSignIn = GoogleSignIn(
    serverClientId: '562037381-fe32lcko640l5ro6br2aqoaq6ld2feb7.apps.googleusercontent.com',
  );
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;
  bool _verifying = false;
  bool _googleLoading = false;
  bool _emailLoading = false;
  int _authTab = 0; // 0 = phone, 1 = email
  int _resendTimer = 0;
  String _error = '';
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    _shakeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    _shakeController.forward(from: 0);
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      _showError('Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _signIn(credential);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() { _loading = false; _error = e.message ?? 'OTP failed'; });
          }
        },
        codeSent: (vid, token) {
          if (mounted) {
            setState(() {
              _verificationId = vid;
              _otpSent = true;
              _loading = false;
            });
            _startResendTimer();
          }
        },
        codeAutoRetrievalTimeout: (vid) {
          _verificationId = vid;
        },
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6 || _verificationId == null) return;
    setState(() { _verifying = true; _error = ''; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signIn(credential);
    } catch (e) {
      if (mounted) {
        setState(() { _verifying = false; _error = 'OTP verification failed: $e'; });
      }
    }
  }

  Future<void> _signIn(AuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? _phoneController.text.replaceAll(RegExp(r'\s+'), '');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', phone);
      if (prefs.getString('name') == null || prefs.getString('name')!.isEmpty) {
        final name = await _promptName();
        if (name != null && name.isNotEmpty) {
          await prefs.setString('name', name);
        }
      }
      final name = prefs.getString('name') ?? '';
      try {
        await http.post(
          Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'name': name}),
        );
      } catch (_) {}
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, phone);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) setState(() { _verifying = false; _error = 'Verification failed: ${e.toString()}'; });
    }
  }

  Future<String?> _promptName() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('What should we call you?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 15,
          decoration: const InputDecoration(
            hintText: 'Your name (max 15 chars)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return name;
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = ''; });
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() { _googleLoading = false; });
        return;
      }

      if (!mounted) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user after sign in');

      final email = user.email ?? googleUser.email;
      final name = user.displayName ?? googleUser.displayName ?? 'User';
      final photoUrl = user.photoURL ?? googleUser.photoUrl;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', email);
      await prefs.setString('email', email);
      await prefs.setString('name', name);
      if (photoUrl != null) await prefs.setString('photo_url', photoUrl);

      try {
        await http.post(
          Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': email, 'email': email, 'name': name}),
        );
      } catch (_) {}

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, email);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) setState(() { _googleLoading = false; _error = 'Google sign in failed: ${e.toString()}'; });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final pass = _passController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _showError('Enter email and password');
      return;
    }
    setState(() { _emailLoading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
    } catch (_) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      } catch (e) {
        if (mounted) setState(() { _emailLoading = false; _error = 'Failed: ${e.toString()}'; });
        return;
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) setState(() { _emailLoading = false; _error = 'Sign in failed'; }); return; }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', email);
    await prefs.setString('email', email);
    await prefs.setString('name', email.split('@').first);
    try {
      await http.post(
        Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': email, 'email': email, 'name': email.split('@').first}),
      );
    } catch (_) {}
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, email);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  Future<void> _continueAsGuest() async {
    final guestId = 'guest_${Random().nextInt(999999)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', guestId);
    if (prefs.getString('name') == null || prefs.getString('name')!.isEmpty) {
      final name = await _promptName();
      if (name != null && name.isNotEmpty) {
        await prefs.setString('name', name);
      }
    }
    final name = prefs.getString('name') ?? 'Guest';
    try {
      await http.post(
        Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': guestId, 'name': name}),
      );
    } catch (_) {}
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, guestId);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  void _onOtpChange(int index, String val) {
    if (val.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.08),
                // App icon
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight]),
                    boxShadow: [
                      BoxShadow(
                        color: MacroSnapTheme.emerald.withOpacity( 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Welcome to MacroSnap',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Track your meals, hit your macros',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),

                // Google Sign-In
                SizedBox(
                  width: double.infinity, height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity( isDark ? 0.3 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _googleLoading ? null : _signInWithGoogle,
                        child: Center(
                          child: _googleLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(
                                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                      width: 22, height: 22,
                                      errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Log in with Google',
                                      style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or', style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : const Color(0xFF94A3B8))),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                    ],
                  ),
                ),

                // Auth method tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _authTab = 0; _error = ''; _otpSent = false; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _authTab == 0 ? (isDark ? MacroSnapTheme.cardDark : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _authTab == 0 ? [
                                BoxShadow(color: Colors.black.withOpacity( 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                              ] : [],
                            ),
                            child: Text('Phone', textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: _authTab == 0
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _authTab = 1; _error = ''; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _authTab == 1 ? (isDark ? MacroSnapTheme.cardDark : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _authTab == 1 ? [
                                BoxShadow(color: Colors.black.withOpacity( 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                              ] : [],
                            ),
                            child: Text('Email', textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: _authTab == 1
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Error banner
                if (_error.isNotEmpty)
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Transform.translate(
                          offset: Offset(sin(_shakeController.value * 4 * 3.14) * 6, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? MacroSnapTheme.rose.withOpacity( 0.15) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: isDark ? MacroSnapTheme.rose : const Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error, style: TextStyle(fontSize: 13, color: isDark ? MacroSnapTheme.rose : const Color(0xFFDC2626)))),
                        ],
                      ),
                    ),
                  ),

                // Phone auth
                if (_authTab == 0 && !_otpSent)
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '+91 98765 43210',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icon(Icons.phone_outlined, size: 20, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                if (_authTab == 0 && _otpSent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (i) => SizedBox(
                      width: 48, height: 56,
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: MacroSnapTheme.emerald, width: 2),
                          ),
                        ),
                        onChanged: (v) => _onOtpChange(i, v),
                      ),
                    )),
                  ),
                  const SizedBox(height: 18),
                  if (_resendTimer > 0)
                    Text('Resend in ${_resendTimer}s', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 13))
                  else
                    InkWell(
                      onTap: _sendOtp,
                      child: Text('Resend OTP', style: TextStyle(color: MacroSnapTheme.emerald, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],

                // Email auth
                if (_authTab == 1) ...[
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.email_outlined, size: 20, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _passController,
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icon(Icons.lock_outlined, size: 20, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ],

                const SizedBox(height: 20),
                if (_authTab == 0)
                  GradientButton(
                    label: _otpSent ? 'Verify OTP' : 'Send OTP',
                    loading: _loading || _verifying,
                    onPressed: _otpSent ? _verifyOtp : _sendOtp,
                    height: 56,
                  )
                else
                  GradientButton(
                    label: 'Log in with Email',
                    loading: _emailLoading,
                    onPressed: _signInWithEmail,
                    height: 56,
                  ),

                const SizedBox(height: 16),
                InkWell(
                  onTap: _continueAsGuest,
                  child: Text('Continue as Guest',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 32),
                Text("By continuing, you agree to our Terms & Privacy Policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

