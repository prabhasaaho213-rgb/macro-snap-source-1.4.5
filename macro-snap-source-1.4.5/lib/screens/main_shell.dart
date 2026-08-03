import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_nav.dart';
import '../core/theme.dart';
import '../services/rate_us_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_status_service.dart';
import 'home_screen.dart';
import 'habits_tab.dart';
import 'scan_screen.dart';
import 'subscription_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Direction of the last tab change: +1 = moving to a higher index (new
  /// page slides in from the right), -1 = moving to a lower index (new page
  /// slides in from the left). Drives the swipe-feel slide transition.
  int _slideDirection = 1;

  /// Stable key for the Scan tab, regenerated once per entry so the camera
  /// screen isn't remounted on every shell rebuild (a timestamp key used to
  /// change every build, making AnimatedSwitcher recreate ScanScreen — the
  /// source of random "camera failed" re-inits).
  Key? _scanKey;

  @override
  void initState() {
    super.initState();
    _currentIndex = shellTabIndex.value;
    shellTabIndex.addListener(_onShellTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSubscription());
    // Prompt for a Play Store rating after a few launches (best-effort).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RateUsService.onAppLaunch(context);
    });
  }

  /// Single entry point for tab changes (bottom-nav taps, swipes, notification
  /// taps) so every path computes the slide direction and regenerates the Scan
  /// camera key on re-entry.
  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _slideDirection = index > _currentIndex ? 1 : -1;
      if (index == 1) {
        _scanKey = ValueKey('scan_${DateTime.now().millisecondsSinceEpoch}');
      }
      _currentIndex = index;
    });
  }

  /// Stable per-tab key used to tell AnimatedSwitcher which child is incoming.
  Key _tabKey(int index) {
    switch (index) {
      case 0:
        return const ValueKey('HomeTab');
      case 1:
        return _scanKey ??
            (_scanKey =
                ValueKey('scan_${DateTime.now().millisecondsSinceEpoch}'));
      case 2:
        return const ValueKey('HabitsTab');
      default:
        return const ValueKey('HomeTab');
    }
  }

  void _onShellTabChanged() {
    if (mounted) _goToTab(shellTabIndex.value);
  }

  @override
  void dispose() {
    shellTabIndex.removeListener(_onShellTabChanged);
    super.dispose();
  }

  Future<void> _maybeShowSubscription() async {
    await SubscriptionService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    final offered = prefs.getBool('subscription_offered') ?? false;
    final subscribed = SubscriptionService.instance.isSubscribed;
    final phone = prefs.getString('phone');
    if (!offered && !subscribed && phone != null && mounted) {
      await prefs.setBool('subscription_offered', true);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => _proUpsellMini(ctx),
        );
      }
    }
  }

  Widget _proUpsellMini(BuildContext dialogCtx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? MacroSnapTheme.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sparkle icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [MacroSnapTheme.neonGreen, Color(0xFF00CC52)],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.black, size: 28),
          ),
          const SizedBox(height: 18),
          Text('Unlock MacroSnap Pro',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 14),

          // Feature rows
          _proFeature(Icons.photo_camera_rounded, 'Unlimited AI food scans', isDark),
          const SizedBox(height: 12),
          _proFeature(Icons.favorite_rounded, 'Unlimited habit tracking', isDark),
          const SizedBox(height: 12),
          _proFeature(Icons.cloud_upload_rounded, 'Cloud backup & restore', isDark),
          const SizedBox(height: 12),
          _proFeature(Icons.insights_rounded, 'Weekly auto-insights & trends', isDark),

          const SizedBox(height: 24),

          // Price & CTA
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MacroSnapTheme.neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('SUBSCRIBE - ₹29/mo · AUTO-RENEWS',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 10),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Not now',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: MacroSnapTheme.textTertiary(context),
                )),
          ),
        ],
      ),
    );
  }

  Widget _proFeature(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: MacroSnapTheme.neonGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: MacroSnapTheme.neonGreen, size: 14),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      ],
    );
  }

  /// Build the current tab content with AnimatedSwitcher key for smooth transitions
  Widget _buildTabContent() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(key: _tabKey(0));
      case 1:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goToTab(0);
          },
          child: ScanScreen(key: _tabKey(1)),
        );
      case 2:
        return HabitsTab(key: _tabKey(2));
      default:
        return HomeScreen(key: _tabKey(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = _tabKey(_currentIndex);
    final dir = _slideDirection.toDouble();
    return Scaffold(
      // Live-wire the cloud-backup warning so a dead backend shows a
      // dismissible banner on every tab instead of failing silently.
      body: ListenableBuilder(
        listenable: SyncStatusService.instance,
        builder: (context, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final syncDown = SyncStatusService.instance.backendUnreachable;
          return Column(
            children: [
              if (syncDown) _syncWarningBanner(isDark),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // Swipe left/right anywhere on the tab body to move to the
                  // adjacent tab (Home ⇄ Scan ⇄ Habits).
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() < 300) return;
                    if (velocity < 0) {
                      // Swipe left → next tab
                      if (_currentIndex < 2) _goToTab(_currentIndex + 1);
                    } else {
                      // Swipe right → previous tab
                      if (_currentIndex > 0) _goToTab(_currentIndex - 1);
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      // Directional swipe transition. The INCOMING child (key matches
                      // the current tab) slides in from the side the swipe came from;
                      // the OUTGOING child (stale key) is pushed out the opposite way.
                      // AnimatedSwitcher drives incoming 0→1 and outgoing 1→0, so the
                      // same tween gives slide-in for one and slide-out for the other.
                      final isIncoming = child.key == currentKey;
                      final begin = isIncoming ? Offset(dir, 0) : Offset.zero;
                      final end = isIncoming ? Offset.zero : Offset(-dir, 0);
                      // Incoming tab springs slightly past center then settles back
                      // (easeOutBack overshoots ~10%) — the iOS-style bounce. The
                      // outgoing tab is pushed out with a clean ease-out, no bounce.
                      final curve = isIncoming ? Curves.easeOutBack : Curves.easeOutCubic;
                      return SlideTransition(
                        position: Tween<Offset>(begin: begin, end: end).animate(
                          CurvedAnimation(parent: animation, curve: curve),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _buildTabContent(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// Compact warning strip shown above the tabs whenever cloud backup can't
  /// reach the backend. Dismissible; Retry re-probes the server.
  Widget _syncWarningBanner(bool isDark) {
    final detail = SyncStatusService.instance.lastDetail;
    final fg = isDark ? Colors.white : const Color(0xFF4A2E00);
    final sub = isDark ? Colors.white70 : const Color(0xFF7A5A1E);
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        color: isDark ? const Color(0xFF2A1A00) : const Color(0xFFFFF3E0),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: MacroSnapTheme.neonOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: MacroSnapTheme.neonOrange,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud backup unavailable',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.isEmpty
                        ? 'Your data is safe on this device, but it isn\'t reaching the cloud.'
                        : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: sub),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              visualDensity: VisualDensity.compact,
              onPressed: () => SyncStatusService.instance.probeBackend(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: MacroSnapTheme.neonOrange,
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => SyncStatusService.instance.dismiss(),
              icon: Icon(Icons.close_rounded, size: 20, color: sub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17171D) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => _goToTab(0),
              ),
              _NavItem(
                icon: Icons.camera_alt_rounded,
                label: 'Scan',
                isSelected: _currentIndex == 1,
                isScan: true,
                onTap: () => _goToTab(1),
              ),
              _NavItem(
                icon: Icons.favorite_rounded,
                label: 'Habits',
                isSelected: _currentIndex == 2,
                onTap: () => _goToTab(2),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isScan;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isScan = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isScan) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected
                ? const LinearGradient(colors: [MacroSnapTheme.neonGreen, Color(0xFF00CC52)])
                : LinearGradient(
                    colors: [
                      (isDark ? Colors.white : MacroSnapTheme.neonGreen).withValues(alpha: 0.1),
                      (isDark ? Colors.white : MacroSnapTheme.neonGreen).withValues(alpha: 0.05),
                    ],
                  ),
            border: Border.all(
              color: isSelected
                  ? MacroSnapTheme.neonGreen
                  : (isDark ? Colors.white : MacroSnapTheme.neonGreen).withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white54 : MacroSnapTheme.neonGreen.withValues(alpha: 0.6)),
            size: 24,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? MacroSnapTheme.neonGreen.withValues(alpha: 0.15) : MacroSnapTheme.neonGreen.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? MacroSnapTheme.neonGreen
                  : (MacroSnapTheme.textTertiary(context)),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MacroSnapTheme.neonGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

