import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/diet_profile.dart';
import 'mascot.dart';

/// Shows a full-screen confetti burst with the mascot celebrating (Duolingo-
/// style payoff). Auto-dismisses after ~1.9s; tapping anywhere dismisses it
/// sooner. The returned Future completes once the overlay is gone.
Future<void> showCelebration(
  BuildContext context, {
  required String message,
  String? subMessage,
}) {
  return _pushOverlay(
    context,
    CelebrationOverlay(
      message: message,
      subMessage: subMessage,
      profile: DietPlanService.instance.profile,
    ),
  );
}

/// Special recovery moment: after the user breaks a 3+ day meal streak and
/// starts a fresh one, the mascot **powers up** with golden confetti and an
/// encouraging "Zenkai Boost" message — coming back stronger.
Future<void> showZenkaiBoost(
  BuildContext context, {
  required int brokenStreak,
}) {
  return _pushOverlay(
    context,
    CelebrationOverlay(
      message: 'ZENKAI BOOST! 🔥',
      subMessage:
          'You lost your $brokenStreak-day streak — but you came back '
          'stronger. This is your Zenkai: rise again, new streak, new power.',
      profile: DietPlanService.instance.profile,
      mood: MascotMood.powerUp,
      palette: const [
        Color(0xFFFFB300),
        Color(0xFFFF6B00),
        Color(0xFFFFD54F),
        Color(0xFFFF8C1A),
        Color(0xFFFFE082),
        Color(0xFF00E65C),
        Color(0xFFFFFFFF),
      ],
    ),
  );
}

Future<void> _pushOverlay(BuildContext context, CelebrationOverlay overlay) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => overlay,
    ),
  );
}

class CelebrationOverlay extends StatefulWidget {
  final String message;
  final String? subMessage;
  final DietProfile? profile;

  /// Which mood the mascot celebrates in (default: celebrating bounce +
  /// sparkles; the Zenkai Boost uses the hero power-up instead).
  final MascotMood mood;

  /// Confetti color palette (defaults to the brand palette).
  final List<Color> palette;

  const CelebrationOverlay({
    super.key,
    required this.message,
    this.subMessage,
    this.profile,
    this.mood = MascotMood.celebrating,
    this.palette = const [
      Color(0xFF00E65C),
      Color(0xFFFF007F),
      Color(0xFF7C3AED),
      Color(0xFFFF6B00),
      Color(0xFF00D4FF),
      Color(0xFFFFB300),
      Color(0xFFE8DEFF),
    ],
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _dismiss;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _dismiss = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
    _dismiss.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });
    final rng = math.Random(7);
    _particles = List.generate(90, (i) {
      return _ConfettiParticle(
        x: rng.nextDouble(),
        phase: rng.nextDouble(),
        size: 5 + rng.nextDouble() * 8,
        drift: 0.03 + rng.nextDouble() * 0.08,
        rotation: 2 + rng.nextDouble() * 6,
        color: widget.palette[rng.nextInt(widget.palette.length)],
      );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Falling confetti across the whole screen.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  t: _confetti.value,
                  particles: _particles,
                ),
              ),
            ),
          ),
          // Celebrating mascot + message.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MascotWidget(
                  size: 130,
                  profile: widget.profile,
                  mood: widget.mood,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? MacroSnapTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (widget.subMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: MacroSnapTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double phase;
  final double size;
  final double drift;
  final double rotation;
  final Color color;

  const _ConfettiParticle({
    required this.x,
    required this.phase,
    required this.size,
    required this.drift,
    required this.rotation,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final phase = (p.phase + t) % 1.0;
      final y = phase * (size.height + 40) - 20;
      final x =
          p.x * size.width +
          math.sin(phase * 2 * math.pi) * size.width * p.drift;
      final angle = phase * p.rotation * 2 * math.pi;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        Paint()..color = p.color.withValues(alpha: 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t || old.particles != particles;
}
