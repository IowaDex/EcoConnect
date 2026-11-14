import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Adds pointer-driven motion to any tappable surface.
///
/// The child keeps its own gesture handling (InkWell, GestureDetector, …);
/// this wrapper only tracks the pointer and scales the surface:
///
/// * hover — grows slightly and lifts a couple of pixels;
/// * press — dips below its resting size, so a tap feels physical.
///
/// On touch devices the hover half never fires, and the press half gives the
/// same feedback as a mouse click.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.hoverScale = 1.015,
    this.pressedScale = 0.982,
    this.lift = 2,
    this.enabled = true,
  });

  final Widget child;

  /// Scale while the pointer is over the surface.
  final double hoverScale;

  /// Scale while the pointer is held down.
  final double pressedScale;

  /// Pixels the surface rises on hover. Zero disables the lift.
  final double lift;

  /// Set false to leave the child completely still.
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  void _set({bool? hovered, bool? pressed}) {
    if (!widget.enabled) return;
    final nextHover = hovered ?? _hovered;
    final nextPress = pressed ?? _pressed;
    if (nextHover == _hovered && nextPress == _pressed) return;
    setState(() {
      _hovered = nextHover;
      _pressed = nextPress;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final scale = _pressed
        ? widget.pressedScale
        : (_hovered ? widget.hoverScale : 1.0);

    return MouseRegion(
      onEnter: (_) => _set(hovered: true),
      onExit: (_) => _set(hovered: false, pressed: false),
      child: Listener(
        onPointerDown: (_) => _set(pressed: true),
        onPointerUp: (_) => _set(pressed: false),
        onPointerCancel: (_) => _set(pressed: false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _hovered && !_pressed ? -widget.lift : 0,
              0,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child into place once, on first build.
///
/// Give list items an increasing [index] to stagger a grid or a column without
/// writing a controller per item.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 380),
    this.stagger = const Duration(milliseconds: 45),
  });

  final Widget child;

  /// Position in the list; multiplies [stagger] to delay the start.
  final int index;

  /// Pixels the child travels upward as it appears.
  final double offset;

  final Duration duration;
  final Duration stagger;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = widget.stagger * widget.index;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + widget.duration,
  );

  /// The slice of the controller that is actually animated. Everything before
  /// it is the stagger wait, expressed as a curve interval so no timer is
  /// created (timers would keep widget tests alive).
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds /
          (_delay.inMilliseconds + widget.duration.inMilliseconds),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Counts a number up when it first appears, so dashboard figures read as a
/// live change instead of a static label.
class CountUpText extends StatelessWidget {
  const CountUpText(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
    this.suffix = '',
  });

  final num value;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(
        '$prefix${current.round()}$suffix',
        style: style,
      ),
    );
  }
}

/// A thin progress line that grows from zero when it appears. Used for the
/// route and signature progress bars.
class GrowBar extends StatelessWidget {
  const GrowBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color = AppColors.primary,
    this.background = AppColors.sage,
    this.duration = const Duration(milliseconds: 700),
  });

  /// 0.0 – 1.0.
  final double value;
  final double height;
  final Color color;
  final Color background;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: current,
          minHeight: height,
          backgroundColor: background,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
