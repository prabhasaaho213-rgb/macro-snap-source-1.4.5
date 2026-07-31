import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'confetti_overlay.dart';

/// A full-screen "Day Complete!" celebration overlay inspired by
/// Duolingo / Streaks / Habitly. Shows confetti, expanding pulse rings,
/// an elastic checkmark badge, and a headline — with haptic feedback.
///
/// Wrap it around any screen and flip [show] to true to trigger.
class CelebrationBurst extends StatefulWidget {
  final bool show;
  final Widget child;
  final String title;
  final String? subtitle;
  final String? streakText;

  const CelebrationBurst({
    super.key,
    required this.show,
    required this.child,
    this.title = 'Day Complete!',
    this.subtitle,
    this.streakText,
  });

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _textFade;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    // Elastic pop for the checkmark badge (Duolingo-style)
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.show) {
      _trigger();
    }
  }

  @override
  void didUpdateWidget(covariant CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _trigger();
    }
  }

  void _trigger() {
    _controller.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.show) ...[
          // Confetti rains down across the whole screen
          Positioned.fill(
            child: ConfettiOverlay(
              show: true,
              color1: MacroSnapTheme.neonGreen,
              color2: MacroSnapTheme.neonPink,
              color3: MacroSnapTheme.neonCyan,
              child: const SizedBox.shrink(),
            ),
          ),
          // Centered badge + headline
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulse rings behind the badge
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _pulseRing(1.6),
                              _pulseRing(1.15),
                              Transform.scale(
                                scale: _badgeScale.value,
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        MacroSnapTheme.neonGreen,
                                        Color(0xFF00CC52),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: MacroSnapTheme.neonGreen
                                            .withValues(alpha: 0.45),
                                        blurRadius: 32,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 52,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: _textFade.value,
                          child: Transform.translate(
                            offset: Offset(
                                0, (1 - _textFade.value) * 18),
                            child: Column(
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                            alpha: 0.18),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.subtitle!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: MacroSnapTheme.textSecondary(
                                          context),
                                    ),
                                  ),
                                ],
                                if (widget.streakText != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: MacroSnapTheme.neonPill(
                                        MacroSnapTheme.neonPink),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department_rounded,
                                          color: MacroSnapTheme.neonPink,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          widget.streakText!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: MacroSnapTheme.neonPink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pulseRing(double scale) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rings expand outward as the badge pops in
        final t = (1 - _controller.value * 0.6).clamp(0.0, 1.0);
        return Opacity(
          opacity: _ringOpacity.value * (1 - t),
          child: Transform.scale(
            scale: 0.6 + t * scale,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MacroSnapTheme.neonGreen.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pops a one-shot celebration overlay above any context (fire-and-forget).
/// Returns immediately; the overlay dismisses itself after [duration].
void showCelebration(
  BuildContext context, {
  String title = 'Day Complete!',
  String? subtitle,
  String? streakText,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  _showBurstDialog(context, title, subtitle, streakText, duration);
}

/// Pops a compact "micro-celebration" — a small elastic checkmark badge with
/// a headline pill that fades in, then auto-dismisses. Lighter than the full
/// [showCelebration] burst; ideal for frequent small wins (meal logged,
/// product found, habit created). Fire-and-forget.
void showMiniCelebration(
  BuildContext context, {
  String title = 'Done!',
  String? subtitle,
  Color accent = MacroSnapTheme.neonGreen,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Done',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) {
      return Stack(
        children: [
          // Dismiss on tap anywhere
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _MiniBurstContent(
                  title: title,
                  subtitle: subtitle,
                  accent: accent,
                  autoHide: duration,
                  onDone: () {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Internal content of the compact micro-celebration dialog.
class _MiniBurstContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color accent;
  final Duration autoHide;
  final VoidCallback onDone;

  const _MiniBurstContent({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.autoHide,
    required this.onDone,
  });

  @override
  State<_MiniBurstContent> createState() => _MiniBurstContentState();
}

class _MiniBurstContentState extends State<_MiniBurstContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Elastic pop for the checkmark badge (smaller, snappier than the full burst)
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
    );

    _controller.forward();
    HapticFeedback.lightImpact();
    Future.delayed(widget.autoHide, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _badgeScale.value,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accent,
                      Color.lerp(widget.accent, Colors.black, 0.25)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.black, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: _textFade.value,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? MacroSnapTheme.cardDark.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: widget.accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MacroSnapTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

void _showBurstDialog(
  BuildContext context,
  String title,
  String? subtitle,
  String? streakText,
  Duration duration,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Day complete',
    barrierColor: Colors.black.withValues(alpha: 0.0),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, _) {
      return Stack(
        children: [
          // Dismiss on tap anywhere
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _BurstContent(
                  title: title,
                  subtitle: subtitle,
                  streakText: streakText,
                  autoHide: duration,
                  onDone: () {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Internal content of the one-shot celebration dialog.
class _BurstContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? streakText;
  final Duration autoHide;
  final VoidCallback onDone;

  const _BurstContent({
    required this.title,
    required this.subtitle,
    required this.streakText,
    required this.autoHide,
    required this.onDone,
  });

  @override
  State<_BurstContent> createState() => _BurstContentState();
}

class _BurstContentState extends State<_BurstContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _textFade;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    HapticFeedback.heavyImpact();
    Future.delayed(widget.autoHide, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _Ring(controller: _controller, scale: 1.6, opacity: _ringOpacity),
                  _Ring(controller: _controller, scale: 1.15, opacity: _ringOpacity),
                  Transform.scale(
                    scale: _badgeScale.value,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [MacroSnapTheme.neonGreen, Color(0xFF00CC52)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MacroSnapTheme.neonGreen.withValues(alpha: 0.45),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.black, size: 52),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: _textFade.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _textFade.value) * 18),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MacroSnapTheme.textSecondary(context),
                        ),
                      ),
                    ],
                    if (widget.streakText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: MacroSnapTheme.neonPill(MacroSnapTheme.neonPink),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: MacroSnapTheme.neonPink, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              widget.streakText!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: MacroSnapTheme.neonPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  final AnimationController controller;
  final double scale;
  final Animation<double> opacity;

  const _Ring({
    required this.controller,
    required this.scale,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (1 - controller.value * 0.6).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity.value * (1 - t),
          child: Transform.scale(
            scale: 0.6 + t * scale,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MacroSnapTheme.neonGreen.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
