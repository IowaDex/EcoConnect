import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/boot/boot_progress.dart';
import '../../../core/constants/service_area.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/hex_leaf_logo.dart';
import '../../auth/providers/auth_provider.dart';

/// Page background. Matches the sky in the illustration so the header and the
/// artwork read as one continuous scene.
const Color _pageBg = Color(0xFFE9F4E1);

/// Green used by the entry panel, sampled to continue the illustration's
/// foreground grass.
const Color _panelGreen = Color(0xFF3E8E41);

/// Lighter and deeper ends of the panel gradient, so the sheet reads as a
/// soft surface instead of a flat block butted against the artwork.
const Color _panelGreenTop = Color(0xFF5DA45F);
const Color _panelGreenBottom = Color(0xFF2E6B32);

/// The sheet is deliberately square. Every edge — the fade into the scene and
/// the bottom that meets the screen — is a straight, full-bleed line, so no
/// page background can peek through a corner and read as a white notch.
const BorderRadius _panelCorners = BorderRadius.zero;

/// How long the panel takes to fade and lift into place.
const Duration _panelEntrance = Duration(milliseconds: 700);

/// How long the copy takes to rise into place.
const Duration _introDuration = Duration(milliseconds: 1100);

/// Shortest time the entry slot stays on the truck, so a warm start cannot
/// flash the loader for two frames and vanish. Kept short on purpose — long
/// enough to see the truck move, short enough to not feel like a delay.
const Duration _minBootDuration = Duration(milliseconds: 1000);

/// Fraction of the window the illustration is held to while booting. The rest
/// is pale sky, which is what gives the splash its airy, mostly-empty look.
const double _bootArtShare = 0.46;

/// How long the illustration takes to rise from the lower half to full bleed.
const Duration _artGrow = Duration(milliseconds: 750);

/// The app's first screen and its landing page in one.
///
/// Both states share one composition, which is what makes the hand-off
/// invisible. The page is a two-row column — the artwork, then whatever sits
/// at the bottom of the screen:
///
///   * while booting — the bottom row is a tall band of empty space carrying a
///     single status line, so the artwork only reaches the lower half of the
///     screen and the brand sits alone on the pale sky;
///   * once ready — the bottom row becomes the green panel, which pushes the
///     artwork's bottom edge up with it, so the truck always clears the panel
///     and the scene grows to fill the page.
///
/// Because the artwork is bottom-anchored to whatever the bottom row is, its
/// bottom edge can never end up hidden behind the panel.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  /// Slow Ken Burns drift over the illustration.
  late final AnimationController _drift;

  /// Staggered entrance for the copy.
  late final AnimationController _intro;

  Timer? _minBootTimer;
  bool _minBootDone = false;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
    _intro = AnimationController(vsync: this, duration: _introDuration)
      ..forward();

    // Start the clock on the first *painted* frame, not on initState. On a
    // cold start the engine can take a few hundred milliseconds to paint, and
    // timing from initState spent that budget on an invisible screen — the
    // loader flashed past before the truck GIF had decoded. Anchoring to the
    // first frame gives the boot state its full duration everywhere, and adds
    // nothing on a warm start where the first frame is immediate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _minBootTimer = Timer(_minBootDuration, () {
        if (!mounted) return;
        setState(() => _minBootDone = true);
      });
    });
  }

  @override
  void dispose() {
    _minBootTimer?.cancel();
    _drift.dispose();
    _intro.dispose();
    super.dispose();
  }

  /// The boot step to print under the brand.
  ///
  /// Reads the real pipeline: the session restore is what the app is actually
  /// waiting on, and [BootProgress] carries the earlier steps in case the
  /// first frame lands while they are still running.
  String _bootStatus(AuthProvider? auth) {
    if (auth == null || !auth.isInitialized) return BootProgress.message.value;
    return 'Preparing your barangay feed';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ScreenMetrics.of(context);

    // Null outside the app shell (widget tests, golden previews). There is no
    // session to wait for there, so the entry points show straight away.
    final auth = context.watch<AuthProvider?>();
    final bootDone = auth == null || auth.isInitialized;
    final ready = bootDone && _minBootDone;
    final status = _bootStatus(auth);

    return Scaffold(
      backgroundColor: _pageBg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.heroMaxWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        // Takes whatever the bottom row leaves, so the scene
                        // is always anchored above it.
                        Expanded(
                          child: Stack(
                            // The fade deliberately spills a hair past this
                            // box; see below.
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: _Illustration(
                                  drift: _drift,
                                  metrics: metrics,
                                  width: constraints.maxWidth,
                                  share: ready ? 1.0 : _bootArtShare,
                                ),
                              ),
                              // The sheet has no hard top edge: the bottom of
                              // the artwork dissolves into the panel colour
                              // before the panel starts, so the two surfaces
                              // meet as one gradient instead of a seam.
                              //
                              // The band runs two points past this box so its
                              // bottom row sits *under* the panel instead of
                              // butting against it. Two edges meeting on the
                              // same fractional pixel each cover only part of
                              // that row, and the artwork underneath shows
                              // through as a hairline. The overlap is the same
                              // colour on both sides, so it costs nothing to
                              // look at.
                              if (ready)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: -2,
                                  height: metrics.scale(44, 70) + 2,
                                  child: const _PanelFade(),
                                ),
                            ],
                          ),
                        ),
                        // Animating this row's height is what lifts the
                        // artwork: the panel grows, the scene above it shrinks.
                        // The panel stays fully opaque — the growing window is
                        // what reveals it, so it reads as sliding up from
                        // under the fold rather than fading through the scene.
                        //
                        // Capped at the window height: a resize that shrinks
                        // the window past the panel's current size would
                        // otherwise leave the column taller than the screen.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: height),
                          child: AnimatedSize(
                            duration: _artGrow,
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.bottomCenter,
                            child: ready
                                ? _EntryPanel(intro: _intro, metrics: metrics)
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                    // On a short window the artwork is zoomed in far enough
                    // that the truck can end up behind the wordmark, so the
                    // brand gets a wash of sky to sit on.
                    if (metrics.isShort)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: height * 0.34,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xF2E9F4E1), Color(0x00E9F4E1)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedPadding(
                        duration: _artGrow,
                        curve: Curves.easeOutCubic,
                        // Clears the notch / status bar on every device.
                        padding: EdgeInsets.only(
                          top:
                              (ready ? 6 : height * 0.11) + metrics.padding.top,
                        ),
                        child: _Header(intro: _intro, metrics: metrics),
                      ),
                    ),
                    // The moving truck, sized and placed like the reference:
                    // small, sitting in the middle of the screen, with the
                    // note saying what it is doing directly underneath it.
                    // The GIF loops on its own, so the wheels turn and the
                    // exhaust puffs without a second animation controller.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          opacity: ready ? 0 : 1,
                          child: Align(
                            alignment: const Alignment(0, -0.12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The GIF carries its own transparent margin,
                                // so the box is wider than the truck you see:
                                // ~0.24 of the width renders the truck at the
                                // reference's ~17% of the screen.
                                EcoTruckArt(
                                  width: (constraints.maxWidth * 0.24).clamp(
                                    80.0,
                                    200.0,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: metrics.scale(11, 12.5),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: const Color(0xFF1C4A24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand lockup, tagline and promise, sitting on the pale sky.
class _Header extends StatelessWidget {
  const _Header({required this.intro, required this.metrics});

  final Animation<double> intro;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final hPad = metrics.scale(24, 40);
    // On a short window the paragraph is the first thing to go — the wordmark
    // and the one-line promise still carry the brand.
    final compact = metrics.isShort;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
      child: Column(
        children: [
          _Reveal(
            intro: intro,
            start: 0.02,
            end: 0.40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _Wordmark(
                fontSize: compact
                    ? metrics.scale(24, 30)
                    : metrics.scale(50, 64),
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : metrics.scale(10, 14)),
          _Reveal(
            intro: intro,
            start: 0.18,
            end: 0.55,
            child: Text(
              'Know When, Know Where!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact
                    ? metrics.scale(12, 14)
                    : metrics.scale(16, 20),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C4A24),
              ),
            ),
          ),
          if (!compact) ...[
            SizedBox(height: metrics.scale(6, 8)),
            _Reveal(
              intro: intro,
              start: 0.28,
              end: 0.66,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.scale(22, 52),
                ),
                child: Text(
                  'Real-time garbage truck tracking and timely notifications, '
                  'making waste disposal easier and more convenient.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: metrics.scale(10.5, 13),
                    height: 1.55,
                    color: const Color(0xFF4A6450),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "EC⬡ / CONNECT" — the hex-leaf mark stands in for the O in ECO. The row is
/// baseline-aligned so the mark's bottom sits on the same line as the letters,
/// whatever font the platform hands us.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: fontSize * 0.075,
      color: const Color(0xFF14501C),
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('EC', style: style),
            // The mark is sized to the letters' cap height: its outline reaches
            // 1.03x the box top to bottom, so 0.72 of the font size draws a
            // hexagon as tall as the E and C. A painted box reports no baseline
            // of its own, so the row can't line it up with the letters. The
            // letters' baseline sits about 0.92 of the font size below the top
            // of their line box, so a 0.20 drop lands the bottom of the stroke
            // on the same line as the bottom of the E and C.
            Padding(
              padding: EdgeInsets.only(left: fontSize * 0.13),
              child: Transform.translate(
                offset: Offset(0, fontSize * 0.203),
                child: HexLeafLogo(
                  size: fontSize * 0.72,
                  color: const Color(0xFF14501C),
                  leafColor: const Color(0xFF4CAF50),
                  strokeWidth: fontSize * 0.72 * 0.11,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: fontSize * 0.05),
        Text('CONNECT', style: style),
      ],
    );
  }
}

/// City skyline, hills, road and the collection truck.
///
/// The artwork is laid out at its natural width-fit size and pinned to the
/// bottom of the space it is given, so it never rescales: only the height of
/// the window in front of it changes. The truck therefore stays exactly the
/// same size from the splash through to the landing page.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.drift,
    required this.metrics,
    required this.width,
    required this.share,
  });

  final Animation<double> drift;
  final ScreenMetrics metrics;

  /// Width of the artwork; its height follows the asset's aspect ratio.
  final double width;

  /// Fraction of the available height that is revealed, measured from the
  /// bottom. [LandingScreen] passes a fraction while booting and `1.0` once
  /// the panel is due, and the change is animated here.
  final double share;

  /// `assets/images/splash_city.png` is 941 × 1672.
  static const double _aspect = 1672 / 941;

  @override
  Widget build(BuildContext context) {
    final artHeight = width * _aspect;
    final fade = metrics.scale(70, 110);

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxHeight;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: share),
          duration: _artGrow,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final window = full * value;
            // The dissolve only matters while the top edge is on screen; by
            // the time the artwork fills the page there is nothing above it.
            final veil = ((1 - value) / (1 - _bootArtShare)).clamp(0.0, 1.0);

            return Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                height: window,
                child: ClipRect(
                  child: Stack(
                    children: [
                      // Pinned to the bottom so the road and truck are always
                      // the part that survives the crop, never the empty sky.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: artHeight,
                        child: child!,
                      ),
                      if (veil > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: fade,
                          child: Opacity(
                            opacity: veil,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [_pageBg, Color(0x00E9F4E1)],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: SizedBox(
            height: artHeight,
            child: AnimatedBuilder(
              animation: drift,
              builder: (context, child) => Transform.scale(
                // Scales about the bottom edge, so the road and truck stay
                // put while the skyline breathes.
                scale: 1.0 + drift.value * 0.015,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: Image.asset(
                'assets/images/splash_city.png',
                width: width,
                height: artHeight,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                frameBuilder: _fadeInAsset,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft top edge for the sheet: opaque panel green at the bottom, fully clear
/// at the top. It spans the full width with square corners, so the scene fades
/// into the sheet along one straight horizontal line — no curve at either end
/// and no gap for the page background to show through.
class _PanelFade extends StatelessWidget {
  const _PanelFade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x005DA45F), _panelGreenTop],
          ),
          borderRadius: _panelCorners,
        ),
      ),
    );
  }
}

/// Green sheet with the value proposition and the two entry points.
///
/// Square on every side: the bottom edge sits flush with the screen and the
/// top edge is a straight line under the illustration's fade, so the sheet
/// reads as one flat block of green rather than a floating rounded card.
class _EntryPanel extends StatelessWidget {
  const _EntryPanel({required this.intro, required this.metrics});

  final Animation<double> intro;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final hPad = metrics.scale(20, 34);
    // On a landscape phone every point of panel height is taken straight from
    // the illustration, so the panel tightens up rather than crowding it out.
    final compact = metrics.isShort;

    return TweenAnimationBuilder<double>(
      // The AnimatedSize above reveals the sheet by growing its window; this
      // fades and lifts the sheet itself, so the panel arrives softly instead
      // of snapping up against the artwork.
      tween: Tween<double>(begin: 0, end: 1),
      duration: _panelEntrance,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 26),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_panelGreenTop, _panelGreen, _panelGreenBottom],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: _panelCorners,
        ),
        padding: EdgeInsets.fromLTRB(
          hPad,
          compact ? 14 : 28,
          hPad,
          compact ? 12 : 20,
        ),
        child: SafeArea(
          top: false,
          // When the window is too short for the full panel, the copy is laid
          // out at its natural height and clipped by the sheet instead of
          // throwing an overflow while the panel animates down to size.
          // It stays content-sized whenever the copy does fit.
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Reveal(
                      intro: intro,
                      start: 0.46,
                      end: 0.78,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Smarter waste collection\n'
                          'for Barangay ${ServiceArea.barangay}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact
                                ? metrics.scale(16, 18)
                                : metrics.scale(25, 31),
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 6 : metrics.scale(8, 10)),
                    _Reveal(
                      intro: intro,
                      start: 0.55,
                      end: 0.85,
                      child: Align(
                        child: ConstrainedBox(
                          // A narrower measure, as in the mockup: the promise
                          // reads as two balanced lines instead of one long one.
                          constraints: BoxConstraints(
                            maxWidth: metrics.scale(300, 420),
                          ),
                          child: Text(
                            'Connecting Communities for a Cleaner and Greener '
                            'Tomorrow.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compact
                                  ? metrics.scale(10, 11)
                                  : metrics.scale(12, 14),
                              height: 1.4,
                              color: const Color(0xFFE8F5E9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : metrics.scale(20, 26)),
                    SizedBox(
                      height: compact ? 44 : metrics.scale(58, 66),
                      child: _PressScale(
                        child: FilledButton(
                          onPressed: () => context.go('/signup'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF14501C),
                            elevation: 3,
                            // A green shadow instead of the default grey: the
                            // button reads as lifted off the sheet rather than
                            // pasted onto it.
                            shadowColor: const Color(0x40143A1A),
                            overlayColor: const Color(0x1414501C),
                            shape: const StadiumBorder(),
                            padding: EdgeInsets.symmetric(
                              horizontal: metrics.scale(20, 26),
                            ),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: compact
                                  ? metrics.scale(12.5, 13.5)
                                  : metrics.scale(14, 16),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.15,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Get Started'),
                              SizedBox(width: compact ? 8 : 10),
                              // The arrow rides in its own pale-green disc, so
                              // it sits on the button's centre line instead of
                              // floating beside the label.
                              Container(
                                width: compact ? 20 : metrics.scale(24, 26),
                                height: compact ? 20 : metrics.scale(24, 26),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE7F3E4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: compact
                                      ? 12
                                      : metrics.scale(13, 14),
                                  color: const Color(0xFF14501C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    SizedBox(
                      height: compact ? 42 : metrics.scale(54, 62),
                      child: _PressScale(
                        child: OutlinedButton(
                          onPressed: () => context.go('/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            // A wash of white rather than nothing: the outlined
                            // button reads as a surface on the green sheet
                            // instead of a floating rectangle of text.
                            backgroundColor: const Color(0x1AFFFFFF),
                            side: const BorderSide(
                              color: Color(0x8CFFFFFF),
                              width: 1.2,
                            ),
                            overlayColor: const Color(0x26FFFFFF),
                            shape: const StadiumBorder(),
                            padding: EdgeInsets.symmetric(
                              horizontal: metrics.scale(18, 24),
                            ),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: compact
                                  ? metrics.scale(11.5, 12.5)
                                  : metrics.scale(12.5, 14.5),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
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
        ),
      ),
    );
  }
}

/// Fade an asset in on its first decoded frame instead of popping it in.
Widget _fadeInAsset(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOut,
    child: child,
  );
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

/// Shrinks its child a hair while a finger is held on it, then springs back.
///
/// A [Listener] rather than a gesture recogniser on purpose: it only observes
/// the pointer, so the button keeps the tap, its ripple and its semantics, and
/// the press effect can never swallow a press or leave it stuck on.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
