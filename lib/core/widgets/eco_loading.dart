import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The animated collection truck.
///
/// Ships as a looping GIF so the wheels, exhaust puffs and road all move
/// without a second animation controller fighting the frame budget. The GIF
/// carries its own alpha channel, so it can be dropped straight onto the
/// illustration or onto the green entry panel.
class EcoTruckArt extends StatelessWidget {
  const EcoTruckArt({super.key, this.width = 210});

  final double width;

  static const String asset = 'assets/images/truck_drive.gif';

  /// Intrinsic 508 × 337. Reserved up-front so the loader never reflows
  /// while the first frame is still decoding.
  static const double _aspect = 337 / 508;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * _aspect,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'EcoConnect collection truck on its way',
        // Fade the first decoded frame in, so the loader does not pop.
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }
}

/// Cream panel the truck drives across — the centrepiece of every blocking
/// loading state, matching the dispatch artwork.
class EcoTruckCard extends StatelessWidget {
  const EcoTruckCard({super.key, this.width = 300});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8E6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14351A).withValues(alpha: 0.20),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: EcoTruckArt(width: width - 36),
    );
  }
}

/// Three soft dots that breathe while work is in flight.
class EcoLoadingDots extends StatefulWidget {
  const EcoLoadingDots({
    super.key,
    this.size = 6,
    this.color = AppColors.forest,
  });

  final double size;
  final Color color;

  @override
  State<EcoLoadingDots> createState() => _EcoLoadingDotsState();
}

class _EcoLoadingDotsState extends State<EcoLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: widget.size * 0.9),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    final phase = (_controller.value - index * 0.16) % 1.0;
    final lift = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return Transform.translate(
      offset: Offset(0, -lift * widget.size * 0.7),
      child: Container(
        height: widget.size,
        width: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.35 + lift * 0.65),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The truck on its cream panel — the shared composition behind the entry
/// screen's loading slot and the blocking overlay.
///
/// Deliberately nothing else: the truck is the whole loading state, so the
/// screen reads as one moving object rather than a wall of widgets.
class EcoLoadingBody extends StatelessWidget {
  const EcoLoadingBody({super.key, this.width = 300});

  final double width;

  @override
  Widget build(BuildContext context) => EcoTruckCard(width: width);
}

/// Inline loader for lists, cards and page bodies. Drop-in replacement for a
/// bare spinner: the truck keeps moving, the label says what is loading.
class EcoLoadingView extends StatelessWidget {
  const EcoLoadingView({super.key, this.label, this.truckWidth = 128});

  final String? label;
  final double truckWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EcoTruckArt(width: truckWidth),
            const SizedBox(height: 4),
            const EcoLoadingDots(),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen blocking overlay: the screen behind is blurred and tinted and
/// the truck drives across a cream panel on top.
class EcoLoadingOverlay extends StatelessWidget {
  const EcoLoadingOverlay({super.key, this.message});

  final String? message;

  /// Runs [task] with the overlay pinned above the app, then removes it.
  ///
  /// Uses an [OverlayEntry] rather than a dialog route so it can never be
  /// popped by a stray back gesture or a navigator call inside [task].
  static Future<T> run<T>(
    BuildContext context,
    Future<T> Function() task, {
    String? message,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return task();

    final entry = OverlayEntry(
      builder: (_) => EcoLoadingOverlay(message: message),
    );
    overlay.insert(entry);
    try {
      // Give the overlay one frame so it paints before heavy work begins.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return await task();
    } finally {
      if (entry.mounted) entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: ColoredBox(
                color: const Color(0xFF14361A).withValues(alpha: 0.46),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math
                      .min(constraints.maxWidth - 56, 316.0)
                      .clamp(220.0, 316.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EcoLoadingBody(width: width),
                            if (message != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
