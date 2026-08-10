import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diet_profile.dart';

/// Moods the mascot can express. `celebrating` plays a one-shot bounce +
/// sparkle burst (e.g. right after logging a meal or completing a habit);
/// `powerUp` is the hero mode — spiky golden hair, a fiery aura and a
/// determined face (tied to big streaks). `sad` is a sympathetic,
/// encouraging look (e.g. when a scan fails), and `wave` makes it raise a
/// hand in greeting (the login screen).
enum MascotMood { idle, happy, thinking, celebrating, powerUp, sad, wave }

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
///  * [gender] — long hair + bow vs. spiky hero crop
///  * [skinTone] — named tone from [kMascotSkinTones]
///  * [weightKg] / [heightCm] — subtly rounder body at higher BMI
///  * [mood] — idle bob + periodic blink, happy/celebrating bounce +
///    sparkles, thinking eyes-up pose, and power-up hero mode (aura +
///    golden spiky hair + determined face)
///
/// The outfit is an original martial-arts hero gi (orange with blue
/// accents) in a ready fighting stance — an energetic, "powered-up" look
/// with no copyrighted character elements.
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
  late final AnimationController _transform;
  MascotMood _mood = MascotMood.idle;

  // Pointer-tracking fields for the Duolingo-style "eyes follow your
  // finger" effect. Written during pointer events and read (and eased)
  // inside the AnimatedBuilder each frame — no setState, no timers, so the
  // widget stays safe in widget tests.
  Offset? _lookTarget;
  double _lookX = 0;
  double _lookY = 0;

  void _trackPointer(PointerEvent e) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final half = widget.size / 2;
    final dx = ((local.dx - half) / half).clamp(-1.0, 1.0);
    final dy = ((local.dy - half) / half).clamp(-1.0, 1.0);
    // Ignore pointers far outside the character itself.
    if (dx.abs() > 2.0 || dy.abs() > 2.0) return;
    _lookTarget = Offset(dx, dy);
  }

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
    // One-shot hero transformation (normal hair → golden spikes + flash).
    _transform = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (_mood == MascotMood.celebrating) _react.forward(from: 0);
    if (_mood == MascotMood.powerUp) _transform.forward(from: 0);
  }

  @override
  void didUpdateWidget(MascotWidget old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      setState(() => _mood = widget.mood);
      if (widget.mood == MascotMood.celebrating) {
        _react.forward(from: 0);
      }
      // Play the hair-morph + flash whenever the hero form kicks in.
      if (widget.mood == MascotMood.powerUp) {
        _transform.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _react.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    _react.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _trackPointer,
      onPointerMove: _trackPointer,
      onPointerUp: (_) => _lookTarget = Offset.zero,
      onPointerCancel: (_) => _lookTarget = Offset.zero,
      child: GestureDetector(
        onTap: widget.onTap != null || _mood != MascotMood.thinking
            ? _handleTap
            : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_life, _react, _transform]),
          builder: (context, _) {
            final bob = math.sin(_life.value * 2 * math.pi);
            final breath = 1 + 0.025 * math.sin(_life.value * 4 * math.pi);
            final bounce = _react.value;
            // Ease the eyes toward the pointer target (smooth follow).
            final target = _lookTarget ?? Offset.zero;
            _lookX += (target.dx - _lookX) * 0.3;
            _lookY += (target.dy - _lookY) * 0.3;
            // Blink at the end of each idle cycle (no timers — keeps the
            // widget safe in widget tests that forbid pending Timers).
            final happyNow = _mood == MascotMood.happy || bounce > 0.05;
            final powerUp = _mood == MascotMood.powerUp;
            final sad = _mood == MascotMood.sad;
            final wave = _mood == MascotMood.wave;
            final blink =
                _life.value > 0.92 && !happyNow && !powerUp && !sad && !wave;
            // Gentle squash on the bounce: taller at the top of the hop.
            final scaleY = breath * (1 + 0.18 * bounce);
            final scaleX = breath * (1 - 0.10 * bounce);
            // Subtle head sway so the character feels alive between bobs.
            final sway = 0.045 * math.sin(_life.value * 2 * math.pi * 0.6);
            return Transform.rotate(
              angle: sway,
              child: Transform.translate(
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
                        powerUp: powerUp,
                        sad: sad,
                        wave: wave,
                        lookX: _lookX,
                        lookY: _lookY,
                        transform: _transform.value,
                        headOnly: widget.headOnly,
                        t: _life.value,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
  final bool powerUp;
  final bool sad;
  final bool wave;
  final double lookX; // -1..1 pointer-follow direction
  final double lookY;
  final double transform; // 0..1 hero transformation progress
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
    required this.powerUp,
    required this.sad,
    required this.wave,
    required this.lookX,
    required this.lookY,
    required this.transform,
    required this.headOnly,
    required this.t,
  });

  static const _green = Color(0xFF00E65C);
  Color get _skin => kMascotSkinTones[skinTone] ?? kMascotSkinTones['medium']!;
  Color get _hair => const Color(0xFF2B2118);

  /// Original martial-arts gi: classic hero orange top, deep blue
  /// undershirt/belt/bands (the "mini Goku" palette).
  Color get _giOrange => const Color(0xFFFF8A00);
  Color get _giOrangeLight => const Color(0xFFFFA733);
  Color get _giBlue => const Color(0xFF2456C8);
  Color get _cheek => const Color(0xFFFF8A8A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.40);
    final r = s * 0.30;

    if (powerUp) _drawAura(canvas, s, c, transform);
    if (!headOnly) {
      _drawBody(canvas, s);
      _drawArms(canvas, s);
      _drawLegs(canvas, s);
    }
    _drawHead(canvas, c, r);
    _drawHair(canvas, c, r);
    _drawFace(canvas, c, r);
    if (powerUp) _drawFlash(canvas, c, s, r, transform);
    if (celebrating > 0) _drawSparkles(canvas, s, c);
  }

  /// 0..1 smoothstep easing (no Curves dependency needed in the painter).
  double _smoothstep(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  /// Fiery power-up halo + rising embers behind the character. Fades in
  /// together with the hero transformation.
  void _drawAura(Canvas canvas, double s, Offset c, double transformT) {
    final inT = 0.15 + 0.85 * _smoothstep(transformT);
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB300).withValues(alpha: (0.5 + 0.25 * pulse) * inT),
          const Color(0xFFFF6B00).withValues(alpha: 0.16 * inT),
          Colors.transparent,
        ],
        stops: const [0.12, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: s * 0.72));
    canvas.drawCircle(c, s * 0.72, glow);
    final ember = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.8 * inT);
    for (var i = 0; i < 6; i++) {
      final phase = (t + i / 6) % 1.0;
      final angle = i * math.pi / 3 + 0.3;
      final radius = s * (0.60 + 0.08 * math.sin(phase * 2 * math.pi));
      final p = Offset(
        c.dx + math.cos(angle) * radius,
        c.dy + math.sin(angle) * radius - phase * s * 0.05,
      );
      canvas.drawCircle(p, s * (0.016 + 0.010 * pulse), ember);
    }
    // Expanding energy shockwave at the feet — the "charging up" ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..color = const Color(
        0xFFFFB300,
      ).withValues(alpha: (0.45 + 0.35 * pulse) * inT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, s * 0.97),
        width: s * (0.46 + 0.14 * pulse),
        height: s * 0.13,
      ),
      ring,
    );
  }

  /// Anime-style flash + expanding ring that peaks mid-transformation and
  /// hides the hair crossfade underneath (classic "power up!" moment).
  void _drawFlash(
    Canvas canvas,
    Offset c,
    double s,
    double r,
    double transformT,
  ) {
    if (transformT <= 0.01 || transformT >= 0.99) return;
    final intensity = math.sin(transformT * math.pi); // 0 → 1 → 0
    final radius = s * (0.55 + 1.7 * transformT);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9 * intensity),
          const Color(0xFFFFD54F).withValues(alpha: 0.5 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    canvas.drawCircle(c, radius, glow);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035 * (1 - transformT)
      ..color = Colors.white.withValues(alpha: 0.9 * intensity);
    canvas.drawCircle(c, radius, ring);
  }

  /// Golden spiky hair for hero (power-up) mode — an original "super" look.
  void _drawSpikyHair(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = const Color(0xFFFFB300);
    const spikes = 8;
    for (var i = 0; i < spikes; i++) {
      // Angle across the top arc of the head (left-top → right-top).
      final a = math.pi * (1.14 + 0.72 * i / (spikes - 1));
      final base = r * 0.90;
      final tip = r * (1.18 + 0.10 * math.sin(i * 1.7));
      final p = Path()
        ..moveTo(
          c.dx + math.cos(a - 0.13) * base,
          c.dy + math.sin(a - 0.13) * base,
        )
        ..lineTo(c.dx + math.cos(a) * tip, c.dy + math.sin(a) * tip)
        ..lineTo(
          c.dx + math.cos(a + 0.13) * base,
          c.dy + math.sin(a + 0.13) * base,
        )
        ..close();
      canvas.drawPath(p, paint);
    }
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
    if (powerUp) {
      final e = _smoothstep(transform);
      if (e >= 0.98) {
        // Transformation done — steady golden hero hair.
        _drawSpikyHair(canvas, c, r);
        return;
      }
      // Crossfade: the normal hair fades out while golden spikes grow in.
      // The bright flash (drawn over the face) hides the swap mid-way.
      _drawNormalHair(
        canvas,
        c,
        r,
        Paint()..color = _hair.withValues(alpha: 1 - e),
      );
      _drawGrowingSpikes(canvas, c, r, e);
      return;
    }
    _drawNormalHair(canvas, c, r);
  }

  /// The character's everyday hair (long + bow for girls, spiky crop for
  /// boys). Pass [paintOverride] to fade it during the hero transform.
  void _drawNormalHair(
    Canvas canvas,
    Offset c,
    double r, [
    Paint? paintOverride,
  ]) {
    final paint = paintOverride ?? (Paint()..color = _hair);
    final hairPath = Path();
    if (gender == Gender.female) {
      // Long hair: sides framing the face + a hero ponytail (bun + tail)
      // on top instead of a bow, so she matches the martial-arts look.
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
      // Ponytail: tight bun on top + a tail sweeping back — a martial-arts
      // look instead of the old bow, so she matches the hero style.
      final bunPaint = Paint()..color = _hair;
      canvas.drawCircle(
        Offset(c.dx + r * 0.10, c.dy - r * 0.98),
        r * 0.16,
        bunPaint,
      );
      final tail = Path()
        ..moveTo(c.dx + r * 0.22, c.dy - r * 0.96)
        ..quadraticBezierTo(
          c.dx + r * 0.62,
          c.dy - r * 1.18,
          c.dx + r * 0.95,
          c.dy - r * 0.72,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.78,
          c.dy - r * 0.55,
          c.dx + r * 0.60,
          c.dy - r * 0.60,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.45,
          c.dy - r * 0.85,
          c.dx + r * 0.22,
          c.dy - r * 0.96,
        )
        ..close();
      canvas.drawPath(tail, paint);
    } else {
      // Spiky dark hero crop — an original anime-style look.
      _drawSpikyDarkHair(canvas, c, r, paintOverride);
    }
  }

  /// Golden power-up spikes that grow outward as the transform progresses.
  /// At [e] = 1 the shape matches [_drawSpikyHair] exactly, so there's no
  /// visible pop when the steady hero hair takes over.
  void _drawGrowingSpikes(Canvas canvas, Offset c, double r, double e) {
    final paint = Paint()..color = const Color(0xFFFFB300).withValues(alpha: e);
    const spikes = 8;
    for (var i = 0; i < spikes; i++) {
      final a = math.pi * (1.14 + 0.72 * i / (spikes - 1));
      final base = r * 0.90;
      final tip = r * (1.18 + 0.10 * math.sin(i * 1.7)) * (0.30 + 0.70 * e);
      final p = Path()
        ..moveTo(
          c.dx + math.cos(a - 0.13) * base,
          c.dy + math.sin(a - 0.13) * base,
        )
        ..lineTo(c.dx + math.cos(a) * tip, c.dy + math.sin(a) * tip)
        ..lineTo(
          c.dx + math.cos(a + 0.13) * base,
          c.dy + math.sin(a + 0.13) * base,
        )
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  /// Original spiky dark hair for the default hero look — tall, sharp
  /// anime spikes with a forward-swept bang (the signature "mini Goku"
  /// silhouette, drawn from scratch so it stays original).
  void _drawSpikyDarkHair(
    Canvas canvas,
    Offset c,
    double r, [
    Paint? paintOverride,
  ]) {
    final paint = paintOverride ?? (Paint()..color = _hair);
    // Tall spikes fanning over the crown (left → right), each one a sharp
    // triangle that leans outward for that wind-swept hero look.
    const spikes = 9;
    for (var i = 0; i < spikes; i++) {
      final a = math.pi * (1.08 + 0.84 * i / (spikes - 1));
      final base = r * 0.94;
      // Taller at the center, slightly shorter at the sides; a little
      // per-spike jitter keeps it organic, not geometric.
      final centerBias = 1.0 - 0.30 * (0.5 - (i / (spikes - 1) - 0.5)).abs() * 2;
      final tip = r * (1.42 + 0.12 * math.sin(i * 1.7)) * centerBias;
      // Wider at the base for chunkier, more readable spikes.
      final halfBase = r * (0.13 + 0.04 * math.sin(i * 2.3));
      final p = Path()
        ..moveTo(c.dx + math.cos(a - halfBase / base) * base,
            c.dy + math.sin(a - halfBase / base) * base)
        ..lineTo(c.dx + math.cos(a) * tip, c.dy + math.sin(a) * tip)
        ..lineTo(c.dx + math.cos(a + halfBase / base) * base,
            c.dy + math.sin(a + halfBase / base) * base)
        ..close();
      canvas.drawPath(p, paint);
    }
    // Forward-swept bang: three sharp strands falling over the forehead
    // (left, center, right) — the unmistakable hero fringe.
    final bang = Path()
      ..moveTo(c.dx - r * 0.78, c.dy - r * 0.30)
      ..lineTo(c.dx - r * 0.52, c.dy + r * 0.18)
      ..lineTo(c.dx - r * 0.30, c.dy - r * 0.16)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.30)
      ..lineTo(c.dx + r * 0.08, c.dy - r * 0.10)
      ..lineTo(c.dx + r * 0.30, c.dy + r * 0.20)
      ..lineTo(c.dx + r * 0.55, c.dy - r * 0.14)
      ..lineTo(c.dx + r * 0.72, c.dy + r * 0.02)
      ..quadraticBezierTo(
        c.dx + r * 0.86,
        c.dy - r * 0.24,
        c.dx + r * 0.76,
        c.dy - r * 0.42,
      )
      ..quadraticBezierTo(
        c.dx,
        c.dy - r * 0.92,
        c.dx - r * 0.76,
        c.dy - r * 0.42,
      )
      ..close();
    canvas.drawPath(bang, paint);
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    // Determined brows in hero mode (angled inward, above the eyes).
    if (powerUp) {
      final brow = Paint()
        ..color = _hair
        ..strokeWidth = r * 0.075
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx - r * 0.52, c.dy - r * 0.30),
        Offset(c.dx - r * 0.16, c.dy - r * 0.17),
        brow,
      );
      canvas.drawLine(
        Offset(c.dx + r * 0.52, c.dy - r * 0.30),
        Offset(c.dx + r * 0.16, c.dy - r * 0.17),
        brow,
      );
    } else if (sad) {
      // Sympathetic raised brows — inner ends up, gentle and encouraging.
      final brow = Paint()
        ..color = _hair
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx - r * 0.50, c.dy - r * 0.26),
        Offset(c.dx - r * 0.16, c.dy - r * 0.36),
        brow,
      );
      canvas.drawLine(
        Offset(c.dx + r * 0.50, c.dy - r * 0.26),
        Offset(c.dx + r * 0.16, c.dy - r * 0.36),
        brow,
      );
    }
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
      // Open eyes with pupils that follow the pointer (or drift idly).
      // When idle with no pointer, the gaze wanders side to side so the
      // character feels alive (Duolingo-style).
      final driftX = lookX.abs() > 0.02
          ? lookX
          : 0.30 * math.sin(t * 2 * math.pi * 0.55);
      final driftY = lookY.abs() > 0.02
          ? lookY
          : 0.12 * math.sin(t * 2 * math.pi * 0.42);
      final px = r * 0.07 * driftX;
      final py = r * 0.06 * driftY;
      final white = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF1C1C1E);
      final iris = Paint()..color = const Color(0xFF5C3A22); // warm brown (Kairo spec)
      for (final side in [-1.0, 1.0]) {
        final ec = Offset(c.dx + side * r * 0.32, c.dy - r * 0.04);
        canvas.drawCircle(ec, r * 0.13, white);
        canvas.drawCircle(ec, r * 0.09, iris);
        canvas.drawCircle(Offset(ec.dx + px, ec.dy + py), r * 0.045, pupil);
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
    } else if (sad) {
      // Gentle downturned frown — sympathetic, not tragic.
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.40),
          width: r * 0.34,
          height: r * 0.20,
        ),
        1.10 * math.pi,
        0.80 * math.pi,
        false,
        mouth,
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
    final gi = Paint()..color = _giOrange;
    final blue = Paint()..color = _giBlue;
    final cx = s / 2;
    final top = s * 0.60;
    final bottom = s * 0.86;
    final width = s * 0.46 * (1 + 0.30 * roundness);
    // Tapered gi torso (wider shoulders, narrower waist = athletic cut).
    final body = Path()
      ..moveTo(cx - width * 0.56, top)
      ..quadraticBezierTo(
        cx - width * 0.62,
        (top + bottom) / 2,
        cx - width * 0.44,
        bottom,
      )
      ..lineTo(cx + width * 0.44, bottom)
      ..quadraticBezierTo(
        cx + width * 0.62,
        (top + bottom) / 2,
        cx + width * 0.56,
        top,
      )
      ..close();
    canvas.drawPath(body, gi);
    // Gi shoulder seams — the two seams that make the jacket read as a
    // classic hero gi rather than a plain orange torso.
    final seam = Paint()
      ..color = _giOrangeLight
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - width * 0.50, top + s * 0.04),
      Offset(cx - width * 0.34, top + s * 0.20),
      seam,
    );
    canvas.drawLine(
      Offset(cx + width * 0.50, top + s * 0.04),
      Offset(cx + width * 0.34, top + s * 0.20),
      seam,
    );
    // Blue undershirt V peeking out at the collar.
    final collarV = Path()
      ..moveTo(cx - width * 0.20, top + s * 0.02)
      ..lineTo(cx, top + s * 0.16)
      ..lineTo(cx + width * 0.20, top + s * 0.02)
      ..close();
    canvas.drawPath(collarV, blue);
    // Blue belt/sash across the waist.
    final beltY = top + (bottom - top) * 0.62;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, beltY),
          width: width * 1.04,
          height: s * 0.05,
        ),
        Radius.circular(s * 0.025),
      ),
      blue,
    );
    // Belt knot in the middle.
    canvas.drawCircle(Offset(cx, beltY), s * 0.035, blue);
    // Chest emblem — a small original navy spiral/sun mark on the gi
    // (Kairo spec: newly designed, no existing anime logos).
    final emblem = Paint()
      ..color = _giBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    final ec = Offset(cx, top + s * 0.11);
    canvas.drawCircle(ec, s * 0.032, emblem);
    final spiral = Path()
      ..moveTo(ec.dx - s * 0.008, ec.dy)
      ..quadraticBezierTo(
        ec.dx,
        ec.dy - s * 0.030,
        ec.dx + s * 0.022,
        ec.dy - s * 0.012,
      )
      ..quadraticBezierTo(
        ec.dx + s * 0.030,
        ec.dy + s * 0.012,
        ec.dx + s * 0.008,
        ec.dy + s * 0.022,
      )
      ..quadraticBezierTo(
        ec.dx - s * 0.012,
        ec.dy + s * 0.024,
        ec.dx - s * 0.018,
        ec.dy + s * 0.006,
      );
    canvas.drawPath(spiral, emblem);
  }

  void _drawArms(Canvas canvas, double s) {
    final gi = Paint()..color = _giOrange;
    final blue = Paint()..color = _giBlue;
    final skin = Paint()..color = _skin;
    final cx = s / 2;
    final width = s * 0.46 * (1 + 0.30 * roundness);
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(cx + side * width * 0.56, s * 0.63);
      // Waving greeting: the right arm is raised and waves side to side.
      if (wave && side > 0) {
        canvas.save();
        canvas.translate(shoulder.dx, shoulder.dy);
        final waveAngle =
            -math.pi * 0.85 + 0.32 * math.sin(t * 2 * math.pi * 2.4);
        canvas.rotate(waveAngle);
        // Sleeve along the raised arm (drawn upward from the shoulder).
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -s * 0.14),
            width: s * 0.12,
            height: s * 0.22,
          ),
          gi,
        );
        // Blue wristband
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -s * 0.245),
            width: s * 0.11,
            height: s * 0.055,
          ),
          blue,
        );
        // Hand
        canvas.drawCircle(Offset(0, -s * 0.28), s * 0.05, skin);
        canvas.restore();
        continue;
      }
      // Gi sleeve, angled slightly outward — ready fighting stance.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(shoulder.dx + side * s * 0.06, shoulder.dy + s * 0.10),
          width: s * 0.12,
          height: s * 0.19,
        ),
        gi,
      );
      // Forearm
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(shoulder.dx + side * s * 0.09, shoulder.dy + s * 0.20),
          width: s * 0.09,
          height: s * 0.11,
        ),
        skin,
      );
      // Blue wristband
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            shoulder.dx + side * s * 0.09,
            shoulder.dy + s * 0.255,
          ),
          width: s * 0.10,
          height: s * 0.05,
        ),
        blue,
      );
      // Fist
      canvas.drawCircle(
        Offset(shoulder.dx + side * s * 0.10, shoulder.dy + s * 0.30),
        s * 0.05,
        skin,
      );
    }
  }

  void _drawLegs(Canvas canvas, double s) {
    final cx = s / 2;
    final pants = Paint()..color = _giOrange;
    final blue = Paint()..color = _giBlue;
    // Wide ready stance — feet apart.
    final stance = s * 0.22;
    for (final side in [-1.0, 1.0]) {
      final legX = cx + side * stance;
      // Pant leg
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(legX, s * 0.885),
          width: s * 0.13,
          height: s * 0.09,
        ),
        pants,
      );
      // Blue leg band above the boot
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(legX, s * 0.925),
          width: s * 0.14,
          height: s * 0.05,
        ),
        blue,
      );
      // Boot — navy high-top with a white panel (Kairo spec shoes).
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(legX, s * 0.948),
          width: s * 0.15,
          height: s * 0.07,
        ),
        blue,
      );
      final white = Paint()..color = Colors.white;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(legX, s * 0.948),
          width: s * 0.075,
          height: s * 0.035,
        ),
        white,
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
      old.powerUp != powerUp ||
      old.sad != sad ||
      old.wave != wave ||
      old.lookX != lookX ||
      old.lookY != lookY ||
      old.transform != transform ||
      old.headOnly != headOnly ||
      old.t != t;
}
