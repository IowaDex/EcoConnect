import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tips that rotate on the loading card. Kept to three so the page dots stay
/// in step with the copy and the card never outgrows the artwork.
const List<String> kEcoLoadingTips = <String>[
  'Rinse your recyclables before the truck comes. Food residue can spoil a '
      'whole batch of paper and plastic.',
  'Flatten boxes and keep paper dry — soggy cardboard is the fastest way to '
      'get an entire load rejected.',
  'Wrap broken glass and sharp metal before setting it out, so collectors can '
      'handle your load safely.',
];

/// The animated collection truck.
///
/// Ships as a looping GIF so the wheels, exhaust puffs and road all move
/// without a second animation controller fighting the frame budget.
class EcoTruckArt extends StatelessWidget {
  const EcoTruckArt({super.key, this.width = 210});

  final double width;

  static const String asset = 'assets/images/truck_drive.gif';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'EcoConnect collection truck on its way',
    );
  }
}

/// Cream panel the truck drives across — the centrepiece of every loading
/// state, matching the dispatch artwork.
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

/// Frosted card that cycles through household recycling tips while the app
/// works, so waiting feels like part of the product rather than a stall.
class EcoTipCard extends StatefulWidget {
  const EcoTipCard({
    super.key,
    this.width = 300,
    this.tips = kEcoLoadingTips,
    this.interval = const Duration(milliseconds: 4200),
  });

  final double width;
  final List<String> tips;
  final Duration interval;

  @override
  State<EcoTipCard> createState() => _EcoTipCardState();
}

class _EcoTipCardState extends State<EcoTipCard> {
  Timer? _timer;
  Timer? _swap;
  int _index = 0;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    if (widget.tips.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) => _advance());
    }
  }

  /// Fades the current tip out, swaps the copy, then fades the next one in.
  /// A plain cross-fade would draw both tips on top of each other for the
  /// length of the transition, which reads as smeared text.
  void _advance() {
    if (!mounted) return;
    setState(() => _visible = false);
    _swap = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.tips.length;
        _visible = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _swap?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = widget.tips[_index];

    return Container(
      width: widget.width,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14351A).withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PRO TIP',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
              color: Color(0xFFC2921B),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Center(
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Text(
                  tip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D3A22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TipDots(count: widget.tips.length, active: _index),
        ],
      ),
    );
  }
}

class _TipDots extends StatelessWidget {
  const _TipDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 5,
            width: i == active ? 14 : 5,
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.forest
                  : AppColors.forest.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Truck plus rotating tip — the shared composition behind the splash screen
/// and the blocking overlay.
class EcoLoadingBody extends StatelessWidget {
  const EcoLoadingBody({
    super.key,
    this.width = 300,
    this.tipInterval = const Duration(milliseconds: 4200),
  });

  final double width;
  final Duration tipInterval;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EcoTruckCard(width: width),
        const SizedBox(height: 16),
        EcoTipCard(width: width, interval: tipInterval),
      ],
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

/// Full-screen blocking overlay: the screen behind is blurred and tinted, the
/// truck drives across a cream panel, and a tip card rotates underneath.
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
