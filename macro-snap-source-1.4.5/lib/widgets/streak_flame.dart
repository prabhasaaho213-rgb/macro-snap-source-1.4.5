import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// Animated streak flames that grow with your best habit streak:
/// 🔥 1–2 days · 🔥🔥 3–6 days · 🔥🔥🔥 7+ days.
///
/// Each flame flickers on its own phase offset; the whole row pops in with
/// an overshoot spring whenever the tier changes. A glowing "Lv N" badge
/// appears and pops in every 7 days of streak (7 → Lv 1, 14 → Lv 2, …)
/// with a medium haptic on level-up.
class StreakFlame extends StatefulWidget {
  const StreakFlame({super.key, required this.streak, this.fontSize = 16});

  /// Best current streak in days (e.g. HabitStore.totalStreakPower).
  final int streak;

  /// Font size of each 🔥 glyph.
  final double fontSize;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker;

  /// Number of flames: 0 none, 1 for 1–2, 2 for 3–6, 3 for 7+.
  int get _flameCount => widget.streak >= 7 ? 3 : (widget.streak >= 3 ? 2 : (widget.streak >= 1 ? 1 : 0));

  /// Level badge: shown from 7 days, then +1 every full 7 days
  /// (7 → Lv 1, 14 → Lv 2, 21 → Lv 3 …). Floor so level-up lands exactly
  /// on the 7-day boundary instead of a day early.
  int get _level => widget.streak >= 7 ? (widget.streak / 7).floor() : 0;

  @override
  void initState() {
    super.initState();
    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLevel = oldWidget.streak >= 7 ? (oldWidget.streak / 7).floor() : 0;
    if (_level > oldLevel) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _flameCount;
    final level = _level;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _flicker,
          builder: (context, _) {
            final t = _flicker.value * 2 * math.pi;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Row(
                key: ValueKey<int>(count),
                mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (i) {
                  // Phase-shifted sine so flames flicker out of sync.
                  final flicker = 0.5 + 0.5 * math.sin(t + i * 1.1);
                  final scale = 1 + 0.09 * flicker;
                  return Transform.scale(
                    scale: scale,
                    child: Text('🔥',
                        style: TextStyle(fontSize: widget.fontSize)),
                  );
                }),
              ),
            );
          },
        ),
        if (level > 0) ...[
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey<int>(level),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MacroSnapTheme.neonOrange, MacroSnapTheme.neonPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MacroSnapTheme.neonOrange.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.military_tech_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('Lv $level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
