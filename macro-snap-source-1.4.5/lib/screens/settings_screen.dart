import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../services/gemini_service.dart';
import 'subscription_screen.dart';
import 'phone_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = 'User';
  String _email = '';
  bool _subscribed = false;
  String? _subscribedDate;
  String _serverUrl = GeminiService.serverUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'User';
      _email = prefs.getString('email') ?? '';
      _subscribed = prefs.getBool('subscribed') ?? false;
      _subscribedDate = prefs.getString('subscribed_at');
      _serverUrl = GeminiService.serverUrl;
    });
  }

  Future<void> _editServerUrl() async {
    final ctrl = TextEditingController(text: _serverUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Server URL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://your-backend.example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newUrl != null && newUrl.isNotEmpty && newUrl != _serverUrl) {
      await GeminiService.setServerUrl(newUrl);
      setState(() => _serverUrl = GeminiService.serverUrl);
    }
  }

  Future<void> _logout(BuildContext context, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MacroSnapTheme.rose),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty && newName != _name) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', newName);
      setState(() => _name = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surface,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: GestureDetector(
                    onTap: _editName,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(_name, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded, color: Colors.white38, size: 16),
                        ],
                      ),
                      if (_email.isNotEmpty) Text(_email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  )),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_subscribed ? 'Pro Member' : 'Free User',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // Settings list card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _settingTile(Icons.subscriptions_rounded, _subscribed ? 'Manage Subscription' : 'Upgrade to Pro', _subscribed && _subscribedDate != null ? 'Subscribed since ${_subscribedDate!.substring(0, 10)}' : 'Unlock AI meal plans & more', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                }, isDark),
                const Divider(height: 24),
                _settingTile(Icons.dark_mode_rounded, 'Theme', 'Switch between Light, Dark, or System', () => _showThemeDialog(isDark), isDark),
                const Divider(height: 24),
                _settingTile(Icons.dns_outlined, 'Server URL', _serverUrl.isNotEmpty ? _serverUrl : 'Not configured', _editServerUrl, isDark),
                const Divider(height: 24),
                _settingTile(Icons.info_outline_rounded, 'App Version', '1.4.6', null, isDark),
                const Divider(height: 24),
                _settingTile(Icons.mail_outline_rounded, 'Contact Support', 'macrosnap7@gmail.com', () async {
                  final uri = Uri.parse('mailto:macrosnap7@gmail.com');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }, isDark),
                const Divider(height: 24),
                _settingTile(Icons.logout_rounded, 'Log Out', 'Sign out and return to login', () => _logout(context, isDark), isDark),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Made with â¤ï¸ in India', style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeDialog(bool isDark) async {
    final current = themeModeNotifier.value;
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) {
        ThemeMode selected = current;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Choose Theme',
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B))),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: mode,
                  groupValue: selected,
                  title: Text(_themeModeLabel(mode),
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  subtitle: Text(_themeModeSubtitle(mode),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                  activeColor: MacroSnapTheme.emerald,
                  onChanged: (v) {
                    setDialogState(() { selected = v!; });
                  },
                ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result != current) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', result.name);
      themeModeNotifier.value = result;
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'System default';
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
    }
  }

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'Follow your device setting';
      case ThemeMode.light: return 'Always light background';
      case ThemeMode.dark: return 'Always dark background';
    }
  }

  Widget _settingTile(IconData icon, String title, String subtitle, VoidCallback? onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: MacroSnapTheme.emerald.withOpacity( 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: MacroSnapTheme.emerald, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
        ])),
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1), size: 20),
      ]),
    );
  }
}

