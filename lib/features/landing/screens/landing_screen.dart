import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/hex_leaf_logo.dart';

/// Page background. Matches the sky in the illustration so the header and the
/// artwork read as one continuous scene.
const Color _pageBg = Color(0xFFE9F4E1);

/// Green used by the entry panel, sampled to continue the illustration's
/// foreground grass.
const Color _panelGreen = Color(0xFF3E8E41);

/// Public landing page — the first thing a signed-out visitor sees.
///
/// Full-bleed three-band layout: the brand lockup on the pale sky, the barangay
/// illustration filling the middle, then the green panel with the two entry
/// points. The artwork drifts slowly and the copy rises in sequence so
/// "Get Started" is the last thing to land.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  /// Slow Ken Burns drift over the illustration.
  late final AnimationController _drift;

  /// Staggered entrance for the copy and the buttons.
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void dispose() {
    _drift.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The artwork is much taller than it is wide, so its visible crop is
          // driven by the band's height. Tying that height to the width keeps
          // the skyline just under the copy on every screen instead of leaving
          // a dead band of empty sky — and unlike zooming, the truck keeps its
          // size and stays inside the frame.
          final available = constraints.maxHeight - 470;
          final band = math.min(
            constraints.maxWidth * 0.70,
            math.max(180.0, available),
          );

          // On a very short window the fixed bands would collide, so fall back
          // to a scrolling page with a capped illustration.
          if (constraints.maxHeight < 620) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _Header(intro: _intro),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _Illustration(drift: _drift),
                  ),
                  _EntryPanel(intro: _intro),
                ],
              ),
            );
          }

          return Column(
            children: [
              _Header(intro: _intro),
              SizedBox(
                height: band,
                width: double.infinity,
                child: _Illustration(drift: _drift),
              ),
              Expanded(child: _EntryPanel(intro: _intro)),
            ],
          );
        },
      ),
    );
  }
}

/// Brand lockup, tagline and promise, sitting on the pale sky.
class _Header extends StatelessWidget {
  const _Header({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _Reveal(
                  intro: intro,
                  start: 0.02,
                  end: 0.40,
                  child: const _Wordmark(),
                ),
                const SizedBox(height: 10),
                _Reveal(
                  intro: intro,
                  start: 0.18,
                  end: 0.55,
                  child: const Text(
                    'Know When, Know Where!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C4A24),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _Reveal(
                  intro: intro,
                  start: 0.28,
                  end: 0.66,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'Real-time garbage truck tracking and timely '
                      'notifications, making waste disposal easier and more '
                      'convenient.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.55,
                        color: Color(0xFF4A6450),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "EC⬡ / CONNECT" — the hex-leaf mark stands in for the O in ECO, sitting on
/// the text baseline the way a round letter would.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    // Fixed size like the earlier lockup — the wordmark should stay modest so
    // the illustration keeps most of the screen.
    const fontSize = 40.0;
    const style = TextStyle(
      fontSize: fontSize,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: 3,
      color: Color(0xFF14501C),
    );

    return const Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('EC', style: style),
            // Bottom padding equal to the font's descent drops the hexagon
            // onto the baseline, so it reads as the O in ECO.
            Padding(
              padding: EdgeInsets.only(left: 5, bottom: fontSize * 0.19),
              child: HexLeafLogo(
                size: fontSize * 0.8,
                color: Color(0xFF14501C),
                leafColor: Color(0xFF4CAF50),
                strokeWidth: fontSize * 0.8 * 0.11,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text('CONNECT', style: style),
      ],
    );
  }
}

/// City skyline, hills, road and the collection truck.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.drift});

  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: AnimatedBuilder(
            animation: drift,
            builder: (context, child) => Transform.scale(
              // A gentle Ken Burns drift. Scales about the bottom edge so the
              // road and truck stay put while the skyline breathes.
              scale: 1.01 + drift.value * 0.03,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
            child: Image.asset(
              'assets/images/splash_city.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        // Softens the join with the header — the top of the crop is sky, so
        // a page-coloured wash blends the two bands without a visible edge.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE9F4E1),
                  Color(0x99E9F4E1),
                  Color(0x00E9F4E1),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ),
        // Melts the foreground grass into the green panel below.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x003E8E41),
                  Color(0xB33E8E41),
                  Color(0xFF3E8E41),
                ],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Green panel with the value proposition and the two entry points.
class _EntryPanel extends StatelessWidget {
  const _EntryPanel({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _panelGreen,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reveal(
                  intro: intro,
                  start: 0.46,
                  end: 0.78,
                  child: const Text(
                    'Smarter waste collection\nfor every barangay',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                _Reveal(
                  intro: intro,
                  start: 0.55,
                  end: 0.85,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Connecting Communities for a Cleaner and Greener '
                      'Tomorrow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: Color(0xFFE8F5E9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _Reveal(
                  intro: intro,
                  start: 0.68,
                  end: 0.95,
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: () => context.go('/signup'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B5E20),
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get Started'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Reveal(
                  intro: intro,
                  start: 0.78,
                  end: 1.0,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => context.go('/login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.4),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('I already have an account'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade-and-rise reveal driven by a slice of [intro]. Uses a plain
/// [AnimatedBuilder] so no [CurvedAnimation] is allocated on every build.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.intro,
    required this.start,
    required this.end,
    required this.child,
  });

  final Animation<double> intro;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      builder: (context, inner) {
        final span = (end - start).abs() < 0.001 ? 1.0 : (end - start);
        final t = ((intro.value - start) / span).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 16),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}
