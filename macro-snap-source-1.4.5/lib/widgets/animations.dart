import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── PAGE TRANSITIONS (Habit Flow style) ──────────────────────

/// A Hero-style page route that slides up with a spring curve,
/// mimicking the Habit Flow app feel.
Route<T> habitFlowRoute<T>(Widget page) {
  return PageRouteBuilder<T>(      pageBuilder: (_, animation, _) => page,
      transitionsBuilder: (_, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
  );
}

/// A route that slides from the right (like a push nav).
Route<T> slideRightRoute<T>(Widget page) {
  return PageRouteBuilder<T>(      pageBuilder: (_, animation, _) => page,
      transitionsBuilder: (_, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}

// ─── SCALE ON PRESS (micro-interaction) ───────────────────────

/// Wraps a child widget and applies a subtle scale-down + shadow effect
/// on tap, mimicking the Habit Flow card press animation.
class ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  final Duration duration;

  const ScaleOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scaleAmount).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: widget.child,
      ),
    );
  }
}

// ─── STAGGERED LIST ENTRANCE (Habit Flow style) ───────────────

/// A list whose items animate in one by one with a slide+fade.
/// Each item index gets a progressive delay.
class StaggeredList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Duration staggerDelay;

  const StaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.physics,
    this.padding,
    this.staggerDelay = const Duration(milliseconds: 60),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _StaggeredItem(
          index: index,
          staggerDelay: staggerDelay,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Duration staggerDelay;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.staggerDelay,
    required this.child,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(widget.staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: widget.child,
      ),
    );
  }
}

// ─── BOTTOM NAV SPRING INDICATOR ──────────────────────────────

/// An animated indicator dot for bottom nav items with a spring feel.
class SpringNavDot extends StatelessWidget {
  final bool selected;
  final Color color;

  const SpringNavDot({
    super.key,
    required this.selected,
    this.color = const Color(0xFF059669),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      width: selected ? 20 : 4,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

// ─── PULSING ENTRANCE for rings & progress bars ───────────────

/// Animates a value from 0 to [target] over a [duration],
/// used for progress bars and calorie rings on first render.
class AnimatedValue extends StatefulWidget {
  final double target;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;
  final Curve curve;

  const AnimatedValue({
    super.key,
    required this.target,
    required this.builder,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return widget.builder(context, _anim.value * widget.target);
      },
    );
  }
}

// ─── ANIMATED ENTRANCE for any widget ─────────────────────────

/// Wraps any widget with a spring-entrance slide+fade animation.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Offset? slideOffset;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.slideOffset,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.slideOffset ?? const Offset(0, 0.04);
    return SlideTransition(
      position: Tween<Offset>(begin: offset, end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: _controller,
        child: widget.child,
      ),
    );
  }
}

// ─── SHAKE WIDGET (for error feedback) ────────────────────────

class ShakeWidget extends StatefulWidget {
  final AnimationController controller;
  final Widget child;

  const ShakeWidget({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(widget.controller.value * 4 * math.pi) * 6,
            0,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─── ANIMATED PROGRESS BAR ────────────────────────────────────

class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color color;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0);
    }
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
      animation: _anim,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: LinearProgressIndicator(
            value: _anim.value * widget.value,
            minHeight: widget.height,
            backgroundColor:
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
          ),
        );
      },
    );
  }
}
