import 'dart:math';
import 'package:flutter/material.dart';

/// A configurable confetti celebration overlay widget
/// Inspired by the habit tracker's confetti effect
class ConfettiOverlay extends StatefulWidget {
  final bool show;
  final Widget child;
  final Color? color1;
  final Color? color2;
  final Color? color3;

  const ConfettiOverlay({
    super.key,
    required this.show,
    required this.child,
    this.color1,
    this.color2,
    this.color3,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<_ConfettiPiece> _pieces = [];
  final _random = Random();

  static const _colors = [
    Color(0xFF059669),
    Color(0xFF34D399),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.show) {
      _generatePieces();
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _generatePieces();
      _controller.reset();
      _controller.forward();
    }
  }

  void _generatePieces() {
    _pieces.clear();
    for (int i = 0; i < 60; i++) {
      _pieces.add(_ConfettiPiece(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.5,
        speed: 0.5 + _random.nextDouble() * 1.0,
        size: 6 + _random.nextDouble() * 8,
        rotation: _random.nextDouble() * 6.28,
        color: _colors[_random.nextInt(_colors.length)],
        shape: _random.nextInt(3),
        wobble: _random.nextDouble() * 3,
      ));
    }
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
        if (widget.show)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  pieces: _pieces,
                  progress: _animation.value,
                  size: MediaQuery.of(context).size,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final double rotation;
  final Color color;
  final int shape; // 0=rect, 1=circle, 2=star
  final double wobble;

  _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.color,
    required this.shape,
    required this.wobble,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  final Size size;

  _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final piece in pieces) {
      final adjustedProgress = (progress - piece.delay).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final eased = 1 - pow(1 - adjustedProgress, 3).toDouble();
      final y = eased * size.height * 1.2;
      final wobbleX = sin(adjustedProgress * piece.wobble * pi) * 15;
      final x = piece.x * size.width + wobbleX;
      final alpha = (1 - eased * 0.7).clamp(0.0, 1.0);
      final scale = eased < 0.2 ? eased / 0.2 : 1.0;
      final rotation = piece.rotation + adjustedProgress * 4;

      canvas.save();
      canvas.translate(x, -size.height * 0.1 + y);
      canvas.rotate(rotation);
      canvas.scale(scale);

      final paint = Paint()
        ..color = piece.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      final half = piece.size / 2;
      if (piece.shape == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.6),
            const Radius.circular(1),
          ),
          paint,
        );
      } else if (piece.shape == 1) {
        canvas.drawCircle(Offset.zero, half, paint);
      } else {
        final path = Path()
          ..moveTo(0, -half)
          ..lineTo(half * 0.3, -half * 0.3)
          ..lineTo(half, -half * 0.1)
          ..lineTo(half * 0.3, half * 0.1)
          ..lineTo(half * 0.5, half)
          ..lineTo(0, half * 0.4)
          ..lineTo(-half * 0.5, half)
          ..lineTo(-half * 0.3, half * 0.1)
          ..lineTo(-half, -half * 0.1)
          ..lineTo(-half * 0.3, -half * 0.3)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}


