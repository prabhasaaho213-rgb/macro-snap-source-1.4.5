import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Professional MacroSnap logo widget for in-app branding
class LogoWidget extends StatelessWidget {
  final double size;
  final bool showLabel;

  const LogoWidget({
    super.key,
    this.size = 72,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              colors: [MacroSnapTheme.neonGreen, MacroSnapTheme.neonGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: MacroSnapTheme.neonGreen.withValues(alpha: 0.35),
                blurRadius: size * 0.33,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner lighter circle
              Positioned(
                child: Container(
                  width: size * 0.75,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MacroSnapTheme.neonGreen.withValues(alpha: 0.2),
                  ),
                ),
              ),
              // Stylized "M" letter
              CustomPaint(
                size: Size(size * 0.42, size * 0.42),
                painter: _LetterMPainter(),
              ),
              // Accent dot (nutrition leaf)
              Positioned(
                right: size * 0.12,
                top: size * 0.12,
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.09,
                      height: size * 0.09,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFA7F3D0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 12),
          Text(
            'MacroSnap',
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track your macros',
            style: TextStyle(
              fontSize: size * 0.11,
              fontWeight: FontWeight.w500,
              color: MacroSnapTheme.textTertiary(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _LetterMPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = size.width / 2;

    // Left vertical
    path.moveTo(cx - w * 0.35, h * 0.15);
    path.lineTo(cx - w * 0.35, h * 0.85);
    path.lineTo(cx - w * 0.2, h * 0.85);
    path.lineTo(cx - w * 0.2, h * 0.38);
    // Diagonal left to center
    path.lineTo(cx, h * 0.55);
    // Diagonal center to right
    path.lineTo(cx + w * 0.2, h * 0.38);
    path.lineTo(cx + w * 0.2, h * 0.85);
    path.lineTo(cx + w * 0.35, h * 0.85);
    path.lineTo(cx + w * 0.35, h * 0.15);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
