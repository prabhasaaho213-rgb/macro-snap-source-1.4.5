import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingScreen({super.key, required this.nextScreen});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  // Drives the dots / buttons WITHOUT rebuilding the PageView. Rebuilding the
  // PageView from setState() mid-swipe re-lays-out the pages and makes the
  // text flicker during the transition.
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(0);

  static const _pages = [
    _OnboardingPageData(
      emoji: '🏠',
      tabIcon: Icons.home_rounded,
      tabLabel: 'Home',
      title: 'Macro Dashboard',
      subtitle:
          'See your daily calories, protein, carbs & fats at a glance. Track meals, streaks, and weekly progress — all from the Home tab.',
      color: MacroSnapTheme.neonGreen,
    ),
    _OnboardingPageData(
      emoji: '📸',
      tabIcon: Icons.camera_alt_rounded,
      tabLabel: 'Scan',
      title: 'AI Food Scanner',
      subtitle:
          'Snap a photo of any meal and get instant nutrition breakdown. Or scan barcodes on packaged foods — all from the Scan tab.',
      color: MacroSnapTheme.neonCyan,
    ),
    _OnboardingPageData(
      emoji: '💪',
      tabIcon: Icons.favorite_rounded,
      tabLabel: 'Habits',
      title: 'Build Healthy Routines',
      subtitle:
          'Track water intake, create custom habit missions, build streak power, and see your consistency heatmap — all from the Habits tab.',
      color: MacroSnapTheme.neonPurple,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextScreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? MacroSnapTheme.surfaceDark
        : MacroSnapTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (rebuilds alone — the PageView stays untouched).
            ValueListenableBuilder<int>(
              valueListenable: _pageNotifier,
              builder: (context, page, _) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (page < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: MacroSnapTheme.textTertiary(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // PageView — never rebuilt on page change (no flicker).
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => _pageNotifier.value = i,
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(context, _pages[i], isDark),
              ),
            ),

            // Bottom section (dots + CTA) — rebuilds alone.
            ValueListenableBuilder<int>(
              valueListenable: _pageNotifier,
              builder: (context, page, _) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: Column(
                  children: [
                    // Progress dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final isActive = i == page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _pages[page].color
                                : (isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Next / Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: page == _pages.length - 1
                            ? _completeOnboarding
                            : () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _pages[page].color,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          page == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    _OnboardingPageData page,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      // Scroll-safe on short screens / large text scale: content stays
      // vertically centered when it fits, and scrolls instead of overflowing
      // when it doesn't.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tab indicator badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: page.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(page.tabIcon, color: page.color, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        page.tabLabel,
                        style: TextStyle(
                          color: page.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tab',
                        style: TextStyle(
                          color: page.color.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Emoji in large neon container
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(38),
                  ),
                  child: Center(
                    child: Text(
                      page.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Title
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MacroSnapTheme.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String emoji;
  final IconData tabIcon;
  final String tabLabel;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPageData({
    required this.emoji,
    required this.tabIcon,
    required this.tabLabel,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
