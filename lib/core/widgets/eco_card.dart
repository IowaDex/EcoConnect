import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard rounded surface used across EcoConnect.
///
/// One component keeps corner radii, borders, padding and shadows identical
/// on every screen. Pass [onTap] to make the whole card tappable: the card
/// then lifts, deepens its shadow and warms its border while the pointer is
/// over it, and dips slightly while pressed.
class EcoCard extends StatefulWidget {
  const EcoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
    this.borderColor,
    this.elevated = true,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool elevated;
  final EdgeInsetsGeometry? margin;

  @override
  State<EcoCard> createState() => _EcoCardState();
}

class _EcoCardState extends State<EcoCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.onTap != null;

  void _set({bool? hovered, bool? pressed}) {
    final nextHover = hovered ?? _hovered;
    final nextPress = pressed ?? _pressed;
    if (nextHover == _hovered && nextPress == _pressed) return;
    setState(() {
      _hovered = nextHover;
      _pressed = nextPress;
    });
  }

  BoxDecoration _decoration() {
    final radius = BorderRadius.circular(18);
    final baseBorder = widget.borderColor ?? AppColors.sage.withValues(alpha: 0.7);
    return BoxDecoration(
      color: widget.color,
      borderRadius: radius,
      border: Border.all(
        color: _interactive && _hovered
            ? AppColors.primary.withValues(alpha: 0.45)
            : baseBorder,
      ),
      boxShadow: !widget.elevated
          ? null
          : (_interactive && _hovered
              ? AppColors.cardShadowHover
              : AppColors.cardShadow),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) {
      return Container(
        margin: widget.margin,
        padding: widget.padding,
        decoration: _decoration(),
        child: widget.child,
      );
    }

    final scale = _pressed ? 0.985 : (_hovered ? 1.012 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
            margin: widget.margin,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: _decoration(),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                hoverColor: Colors.transparent,
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
