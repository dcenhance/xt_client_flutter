import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Small motion toolkit for the login screen. Everything here honours
/// `MediaQuery.disableAnimations` (Android "remove animations", desktop reduced
/// motion), so the screen still works for people who switch animations off.

bool _reduced(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A slow drifting gradient behind the whole screen. Two blurred colour blobs
/// move on long, offset loops — enough to feel alive without pulling the eye.
class MotionBackdrop extends StatefulWidget {
  const MotionBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<MotionBackdrop> createState() => _MotionBackdropState();
}

class _MotionBackdropState extends State<MotionBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 2 * math.pi;
        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: AppTheme.background),
              child: const SizedBox.expand(),
            ),
            // Warm blob, drifting on a wide ellipse.
            Positioned(
              left: -120 + 60 * math.cos(t),
              top: -90 + 40 * math.sin(t * 1.3),
              child: _blob(AppTheme.accent.withValues(alpha: 0.16), 420),
            ),
            // Cool counter-blob, half a cycle later.
            Positioned(
              right: -140 + 50 * math.cos(t * 0.8 + math.pi),
              bottom: -120 + 45 * math.sin(t * 0.6 + math.pi),
              child: _blob(AppTheme.accent2.withValues(alpha: 0.12), 480),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
}

/// Fades and slides a child in once, optionally after a delay — used to stagger
/// the login form instead of dropping it all on screen at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 18),
    this.duration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (mounted) _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context) && !_c.isCompleted) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(
            widget.offset.dx * (1 - _t.value),
            widget.offset.dy * (1 - _t.value),
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A mark that breathes: a soft glow swells and settles behind it, and the mark
/// itself lifts a hair. Idle motion only — never distracting, never bouncing.
class BreathingMark extends StatefulWidget {
  const BreathingMark({super.key, required this.child, this.size = 96});

  final Widget child;
  final double size;

  @override
  State<BreathingMark> createState() => _BreathingMarkState();
}

class _BreathingMarkState extends State<BreathingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final Animation<double> _breath = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      _c.stop();
      _c.value = 0.35;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final v = _breath.value;
        return Transform.scale(
          scale: 1 + 0.015 * v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.14 + 0.20 * v),
                  blurRadius: widget.size * (0.34 + 0.30 * v),
                  spreadRadius: widget.size * (0.02 + 0.05 * v),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Shakes its child once whenever [tick] changes — a login failure you can feel
/// rather than only read.
class ShakeOnChange extends StatefulWidget {
  const ShakeOnChange({super.key, required this.tick, required this.child});

  final Object? tick;
  final Widget child;

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant ShakeOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick && widget.tick != null) {
      if (_reduced(context)) return;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.isDismissed) return child!;
        // Damped sine: three quick shakes that settle.
        final dx = math.sin(_c.value * math.pi * 6) * 9 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// A button that leans in when pressed and settles back with a spring.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}