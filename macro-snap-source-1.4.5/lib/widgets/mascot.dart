import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diet_profile.dart';

/// Moods the mascot can express. `celebrating` plays a one-shot bounce +
/// sparkle burst (e.g. right after logging a meal or completing a habit).
enum MascotMood { idle, happy, thinking, celebrating }

/// Named skin tones the user can pick from. Keys are stored in the profile.
const Map<String, Color> kMascotSkinTones = {
  'light': Color(0xFFFFE3C2),
  'medium': Color(0xFFF0C091),
  'tan': Color(0xFFD39B6A),
  'brown': Color(0xFFA86B3F),
  'dark': Color(0xFF7A4A28),
};

/// A friendly, chibi-style mascot character (boy or girl) whose look is
/// driven by the user's profile:
///
///  * [gender] — hair cut + bow vs. short crop
///  * [skinTone] — named tone from [kMascotSkinTones]
///  * [weightKg] / [heightCm] — subtly rounder body at higher BMI
///  * [mood] — idle bob + periodic blink, happy/celebrating bounce +
///    sparkles, thinking eyes-up pose
///
/// Tap the mascot to make it bounce and sparkle (if [onTap] is null the
/// bounce still plays, purely as a fun reaction).
class MascotWidget extends StatefulWidget {
  final double size;

  /// Boy or girl — affects the hair style.
  final Gender gender;

  /// One of the keys in [kMascotSkinTones].
  final String skinTone;

  final double weightKg;
  final double heightCm;

  /// Pass null to use the mascot's own defaults for an unset profile.
  final DietProfile? profile;

  final MascotMood mood;
  final VoidCallback? onTap;

  /// Renders only the head (no body/arms/legs) — for tight header spots.
  final bool headOnly;

  const MascotWidget({
    super.key,
    this.size = 96,
    this.gender = Gender.male,
    this.skinTone = 'medium',
    this.weightKg = 70,
    this.heightCm = 170,
    this.profile,
    this.mood = MascotMood.happy,
    this.onTap,
    this.headOnly = false,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with TickerProviderStateMixin {
  late final AnimationController _life;
  late final AnimationController _react;
  MascotMood _mood = MascotMood.idle;

  Gender get _gender => widget.profile?.gender ?? widget.gender;
  String get _skinTone => widget.profile?.skinTone ?? widget.skinTone;
  double get _weight => widget.profile?.weightKg ?? widget.weightKg;
  double get _height => widget.profile?.heightCm ?? widget.heightCm;

  /// 0 (very slim) → 1 (rounder) mapped from BMI so the character's body
  /// gently reflects the user's build without ever looking judgmental.
  double get _roundness {
    final h = _height / 100;
    final bmi = h <= 0 ? 22 : _weight / (h * h);
    return ((bmi - 16) / 14).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _mood = widget.mood;
    _life = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (_mood == MascotMood.celebrating) _react.forward(from: 0);
  }

  @override
  void didUpdateWidget(MascotWidget old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      setState(() => _mood = widget.mood);
      if (widget.mood == MascotMood.celebrating) {
        _react.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _react.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    _react.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap != null || _mood != MascotMood.thinking
          ? _handleTap
          : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_life, _react]),
        builder: (context, _) {
          final bob = math.sin(_life.value * 2 * math.pi);
          final breath = 1 + 0.025 * math.sin(_life.value * 4 * math.pi);
          final bounce = _react.value;
          // Blink at the end of each idle cycle (no timers — keeps the
          // widget safe in widget tests that forbid pending Timers).
          final happyNow = _mood == MascotMood.happy || bounce > 0.05;
          final blink = _life.value > 0.92 && !happyNow;
          // Gentle squash on the bounce: taller at the top of the hop.
          final scaleY = breath * (1 + 0.18 * bounce);
          final scaleX = breath * (1 - 0.10 * bounce);
          return Transform.translate(
            offset: Offset(0, -6 * bob * (1 + bounce)),
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _MascotPainter(
                    roundness: _roundness,
                    gender: _gender,
                    skinTone: _skinTone,
                    blink: blink,
                    happy: happyNow,
                    celebrating: bounce,
                    thinking: _mood == MascotMood.thinking,
                    headOnly: widget.headOnly,
                    t: _life.value,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double roundness;
  final Gender gender;
  final String skinTone;
  final bool blink;
  final bool happy;
  final double celebrating; // 0..1
  final bool thinking;
  final bool headOnly;
  final double t;

  _MascotPainter({
    required this.roundness,
    required this.gender,
    required this.skinTone,
    required this.blink,
    required this.happy,
    required this.celebrating,
    required this.thinking,
    required this.headOnly,
    required this.t,
  });

  static const _green = Color(0xFF00E65C);
  Color get _skin => kMascotSkinTones[skinTone] ?? kMascotSkinTones['medium']!;
  Color get _hair => const Color(0xFF2B2118);
  Color get _shirt =>
      gender == Gender.female ? const Color(0xFFFF4D8D) : _green;
  Color get _cheek => const Color(0xFFFF8A8A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.40);
    final r = s * 0.30;

    if (!headOnly) {
      _drawBody(canvas, s);
      _drawArms(canvas, s);
      _drawLegs(canvas, s);
    }
    _drawHead(canvas, c, r);
    _drawHair(canvas, c, r);
    _drawFace(canvas, c, r);
    if (celebrating > 0) _drawSparkles(canvas, s, c);
  }

  void _drawHead(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = _skin;
    canvas.drawCircle(c, r, paint);
    // Soft gloss highlight
    final gloss = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(c.dx - r * 0.35, c.dy - r * 0.38),
      r * 0.22,
      gloss,
    );
  }

  void _drawHair(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = _hair;
    final hairPath = Path();
    if (gender == Gender.female) {
      // Long hair: sides framing the face + a little bow on top.
      final side = Path()
        ..moveTo(c.dx - r * 0.92, c.dy - r * 0.5)
        ..quadraticBezierTo(
          c.dx - r * 1.25,
          c.dy - r * 0.15,
          c.dx - r * 0.88,
          c.dy + r * 0.55,
        )
        ..quadraticBezierTo(
          c.dx - r * 0.7,
          c.dy + r * 0.62,
          c.dx - r * 0.62,
          c.dy + r * 0.3,
        )
        ..quadraticBezierTo(
          c.dx - r * 0.72,
          c.dy - r * 0.1,
          c.dx - r * 0.55,
          c.dy - r * 0.45,
        )
        ..close();
      canvas.drawPath(side, paint);
      canvas.save();
      // Mirror the left-side hair around the head center.
      canvas.translate(2 * c.dx, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(side, paint);
      canvas.restore();
      // Top cap
      hairPath
        ..moveTo(c.dx - r * 0.92, c.dy - r * 0.3)
        ..quadraticBezierTo(
          c.dx,
          c.dy - r * 1.05,
          c.dx + r * 0.92,
          c.dy - r * 0.3,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.5,
          c.dy - r * 0.62,
          c.dx,
          c.dy - r * 0.55,
        )
        ..quadraticBezierTo(
          c.dx - r * 0.5,
          c.dy - r * 0.62,
          c.dx - r * 0.92,
          c.dy - r * 0.3,
        )
        ..close();
      canvas.drawPath(hairPath, paint);
      // Bow
      final bowPaint = Paint()..color = const Color(0xFFFF4D8D);
      final bow = Path()
        ..moveTo(c.dx, c.dy - r * 0.98)
        ..quadraticBezierTo(
          c.dx - r * 0.28,
          c.dy - r * 1.25,
          c.dx - r * 0.34,
          c.dy - r * 0.92,
        )
        ..quadraticBezierTo(
          c.dx - r * 0.14,
          c.dy - r * 0.78,
          c.dx,
          c.dy - r * 0.92,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.14,
          c.dy - r * 0.78,
          c.dx + r * 0.34,
          c.dy - r * 0.92,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.28,
          c.dy - r * 1.25,
          c.dx,
          c.dy - r * 0.98,
        )
        ..close();
      canvas.drawPath(bow, bowPaint);
    } else {
      // Short crop covering the top of the head.
      hairPath
        ..moveTo(c.dx - r * 0.95, c.dy - r * 0.32)
        ..quadraticBezierTo(
          c.dx - r * 0.9,
          c.dy - r * 0.85,
          c.dx - r * 0.4,
          c.dy - r * 0.95,
        )
        ..quadraticBezierTo(
          c.dx,
          c.dy - r * 1.02,
          c.dx + r * 0.4,
          c.dy - r * 0.95,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.9,
          c.dy - r * 0.85,
          c.dx + r * 0.95,
          c.dy - r * 0.32,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.55,
          c.dy - r * 0.62,
          c.dx,
          c.dy - r * 0.6,
        )
        ..quadraticBezierTo(
          c.dx - r * 0.55,
          c.dy - r * 0.62,
          c.dx - r * 0.95,
          c.dy - r * 0.32,
        )
        ..close();
      canvas.drawPath(hairPath, paint);
    }
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    // Cheeks
    final cheekPaint = Paint()..color = _cheek.withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(c.dx - r * 0.55, c.dy + r * 0.22),
      r * 0.13,
      cheekPaint,
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.55, c.dy + r * 0.22),
      r * 0.13,
      cheekPaint,
    );

    if (thinking) {
      // Eyes looking up + a little "…" bubble.
      final upEye = Paint()
        ..color = const Color(0xFF1C1C1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(c.dx - r * 0.32, c.dy - r * 0.06),
          radius: r * 0.16,
        ),
        0,
        math.pi,
        false,
        upEye,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(c.dx + r * 0.32, c.dy - r * 0.06),
          radius: r * 0.16,
        ),
        0,
        math.pi,
        false,
        upEye,
      );
      _drawThinkingBubble(canvas, c, r);
    } else if (blink) {
      // Closed lids.
      final lid = Paint()
        ..color = const Color(0xFF1C1C1E)
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx - r * 0.46, c.dy),
        Offset(c.dx - r * 0.16, c.dy),
        lid,
      );
      canvas.drawLine(
        Offset(c.dx + r * 0.16, c.dy),
        Offset(c.dx + r * 0.46, c.dy),
        lid,
      );
    } else if (happy) {
      // Happy closed eyes (∪ arcs).
      final arc = Paint()
        ..color = const Color(0xFF1C1C1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(c.dx - r * 0.32, c.dy - r * 0.02),
          radius: r * 0.13,
        ),
        math.pi,
        math.pi,
        false,
        arc,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(c.dx + r * 0.32, c.dy - r * 0.02),
          radius: r * 0.13,
        ),
        math.pi,
        math.pi,
        false,
        arc,
      );
    } else {
      // Open eyes with pupils.
      final white = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF1C1C1E);
      final iris = Paint()..color = const Color(0xFF3D2B1F);
      for (final side in [-1.0, 1.0]) {
        final ec = Offset(c.dx + side * r * 0.32, c.dy - r * 0.04);
        canvas.drawCircle(ec, r * 0.13, white);
        canvas.drawCircle(ec, r * 0.09, iris);
        canvas.drawCircle(ec, r * 0.045, pupil);
        // Glint
        canvas.drawCircle(
          Offset(ec.dx + r * 0.03, ec.dy - r * 0.03),
          r * 0.02,
          Paint()..color = Colors.white,
        );
      }
    }

    // Mouth: open smile while celebrating, small smile otherwise.
    final mouth = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round;
    if (celebrating > 0.05) {
      final open = Paint()
        ..color = const Color(0xFF7A2E1D)
        ..style = PaintingStyle.fill;
      final mouthRect = Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.42),
        width: r * 0.34,
        height: r * 0.3,
      );
      canvas.drawOval(mouthRect, open);
      final tongue = Paint()..color = const Color(0xFFFF7B9C);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.5),
          width: r * 0.2,
          height: r * 0.16,
        ),
        0,
        math.pi,
        false,
        tongue,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.32),
          width: r * 0.42,
          height: r * 0.26,
        ),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        mouth,
      );
    }
  }

  void _drawThinkingBubble(Canvas canvas, Offset c, double r) {
    final dot = Paint()..color = const Color(0xFF9AA0A6);
    final dx = c.dx + r * 1.05;
    final base = c.dy - r * 0.85;
    canvas.drawCircle(Offset(dx, base - r * 0.28), r * 0.06, dot);
    canvas.drawCircle(Offset(dx + r * 0.16, base - r * 0.46), r * 0.045, dot);
    canvas.drawCircle(Offset(dx + r * 0.34, base - r * 0.6), r * 0.035, dot);
  }

  void _drawBody(Canvas canvas, double s) {
    final shirt = Paint()..color = _shirt;
    final cx = s / 2;
    final top = s * 0.60;
    final bottom = s * 0.86;
    final width = s * 0.46 * (1 + 0.30 * roundness);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, (top + bottom) / 2),
        width: width,
        height: bottom - top,
      ),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(body, shirt);
    // Collar
    final collar = Paint()..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawLine(
      Offset(cx - width * 0.18, top + s * 0.02),
      Offset(cx + width * 0.18, top + s * 0.02),
      collar
        ..strokeWidth = s * 0.03
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawArms(Canvas canvas, double s) {
    final shirt = Paint()..color = _shirt;
    final skin = Paint()..color = _skin;
    final cx = s / 2;
    final width = s * 0.46 * (1 + 0.30 * roundness);
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(cx + side * width * 0.52, s * 0.66);
      // Arm
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(shoulder.dx + side * s * 0.03, shoulder.dy + s * 0.10),
          width: s * 0.11,
          height: s * 0.24,
        ),
        shirt,
      );
      // Hand
      canvas.drawCircle(
        Offset(shoulder.dx + side * s * 0.04, shoulder.dy + s * 0.23),
        s * 0.05,
        skin,
      );
    }
  }

  void _drawLegs(Canvas canvas, double s) {
    final cx = s / 2;
    final width = s * 0.46 * (1 + 0.30 * roundness);
    final shoe = Paint()..color = const Color(0xFF374151);
    for (final side in [-1.0, 1.0]) {
      final legCenter = Offset(cx + side * width * 0.22, s * 0.90);
      canvas.drawOval(
        Rect.fromCenter(center: legCenter, width: s * 0.12, height: s * 0.09),
        shoe,
      );
    }
  }

  void _drawSparkles(Canvas canvas, double s, Offset c) {
    final sparkle = Paint()..color = _green.withValues(alpha: celebrating);
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5 + t * 0.6;
      final radius = s * (0.42 + 0.10 * celebrating);
      final p = Offset(
        c.dx + math.cos(angle) * radius,
        c.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(p, s * (0.025 + 0.015 * celebrating), sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.roundness != roundness ||
      old.gender != gender ||
      old.skinTone != skinTone ||
      old.blink != blink ||
      old.happy != happy ||
      old.celebrating != celebrating ||
      old.thinking != thinking ||
      old.headOnly != headOnly ||
      old.t != t;
}
