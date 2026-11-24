import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/motion.dart';
import 'auth_type.dart';

/// The splash scene, pinned to the bottom of whatever box it fills.
///
/// Shared by the entry screens so the artwork never pops mid-paint: it fades
/// in once the decoder has a frame.
class AuthScene extends StatelessWidget {
  const AuthScene({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/images/splash_city.png',
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }
}

/// The round back control that sits over the scene.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({
    super.key,
    required this.onTap,
    this.onDark = false,
    this.tooltip = 'Back',
  });

  final VoidCallback onTap;

  /// True when the button sits on the darkened artwork, where a pale circle
  /// would disappear into the wash.
  final bool onDark;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.82),
        shape: CircleBorder(
          side: BorderSide(
            color: onDark
                ? Colors.white.withValues(alpha: 0.22)
                : AppColors.sage.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 19,
              color: onDark ? Colors.white : AppColors.darkGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet a form sits on: rounded, lifted, and flush with the bottom of the
/// window so it reads as one surface rather than a floating card.
class AuthSheet extends StatelessWidget {
  const AuthSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The barangay badge in the top bar.
///
/// Deliberately the same height and treatment as [AuthBackButton]: the two
/// sit opposite each other with the wordmark between them, so the bar reads as
/// two controls rather than a button and a sticker.
class AuthAreaPill extends StatelessWidget {
  const AuthAreaPill({super.key, this.compact = false, this.onDark = false});

  /// The top bar has no room for the full address, so it shortens to the
  /// barangay name alone.
  final bool compact;

  /// True when the pill sits on the darkened illustration, where a pale pill
  /// with dark text would disappear into the wash.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : AppColors.darkGreen;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.sage.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: 15,
            color: onDark ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 6),
          // Loose so the pill can shrink on a narrow phone or at a large text
          // scale instead of overflowing its own row.
          Flexible(
            child: Text(
              compact ? 'Batasan Hills' : 'Barangay Batasan Hills · Quezon City',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: authSans(
                size: 10.5,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered line in the wide hero's "how it works" list.
@immutable
class AuthHeroStep {
  const AuthHeroStep(this.label);

  final String label;
}

/// The page frame shared by the entry screens.
///
/// A phone stacks the splash scene above a sheet that rides over it; a wide
/// window splits the two side by side. Both compositions keep the back control
/// and the wordmark in the same place, so moving between login, sign-up and
/// password recovery never moves the furniture.
///
/// The hero is the only part that changes per screen: pass its [headline],
/// supporting line and — on a tall window — the [heroSteps] the screen is
/// about to walk the visitor through.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.form,
    required this.headline,
    required this.heroSubtitle,
    required this.onBack,
    this.backTooltip = 'Back',
    this.heroSteps = const [],
  });

  final Widget form;
  final String headline;
  final String heroSubtitle;
  final VoidCallback onBack;
  final String backTooltip;
  final List<AuthHeroStep> heroSteps;

  /// Above this window width the page splits into an illustration pane and a
  /// form pane instead of stacking the two. Chosen so a small laptop or a
  /// tablet in landscape gets the desktop composition, not a stretched phone.
  static const double splitBreakpoint = 900;

  /// How far the sheet overlaps the artwork, so its rounded corners sit on the
  /// scene instead of on a flat band of colour.
  static const double _sheetOverlap = 28;

  @override
  Widget build(BuildContext context) {
    final metrics = ScreenMetrics.of(context);
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: metrics.size.width >= splitBreakpoint
          ? _wide(metrics)
          : _stacked(metrics),
    );
  }

  /// Tablet-landscape and desktop composition: the scene and the form sit side
  /// by side, each with a full-height column of its own.
  Widget _wide(ScreenMetrics metrics) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: _hero(
            wide: true,
            showHeadline: metrics.size.height >= 560,
            showSubtitle: metrics.size.height >= 680,
            showSteps: metrics.size.height >= 700,
            topInset: metrics.padding.top + 28,
            bottomInset: 40 + metrics.padding.bottom,
          ),
        ),
        Expanded(
          flex: 9,
          child: Container(
            color: AppColors.creamBright,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 44,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: form,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Phone and portrait-tablet composition: the scene across the top, the form
  /// on a sheet that rides over the bottom of it.
  Widget _stacked(ScreenMetrics metrics) {
    final height = metrics.size.height;
    final keyboardUp = metrics.viewInsets.bottom > 0;

    // The scene gives up its height as the window shrinks: a short landscape
    // phone gets a strip, and an open keyboard leaves only the brand row.
    final double heroHeight;
    if (keyboardUp) {
      heroHeight = (height * 0.22).clamp(120.0, 170.0);
    } else if (metrics.isShort) {
      heroHeight = (height * 0.36).clamp(170.0, 290.0);
    } else {
      heroHeight = (height * 0.38).clamp(230.0, 380.0);
    }

    final gutter = formGutter(metrics.size.width);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight,
          child: _hero(
            wide: false,
            // A headline needs room for two lines under the brand row. Below
            // this the band shows the wordmark alone rather than cramming
            // display type into a strip.
            showHeadline: !keyboardUp && heroHeight >= 230,
            showSubtitle: !keyboardUp && heroHeight >= 300,
            showSteps: false,
            topInset: metrics.padding.top + 8,
            // While the keyboard is up the sheet covers nothing, so the band
            // does not need to reserve room for the overlap.
            bottomInset: keyboardUp ? 12 : _sheetOverlap + 18,
          ),
        ),
        Positioned.fill(
          top: heroHeight - _sheetOverlap,
          child: AuthSheet(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                28,
                gutter,
                24 + metrics.padding.bottom,
              ),
              child: form,
            ),
          ),
        ),
      ],
    );
  }

  /// The splash scene with the brand, the headline and — on a wide window —
  /// the numbered steps the screen is about to walk through.
  ///
  /// The scene is washed at the top so the wordmark stays legible against the
  /// sky, and washed dark at the bottom so white display type reads over the
  /// road. Between the two washes the artwork is untouched, which is what
  /// keeps the truck visible.
  Widget _hero({
    required bool wide,
    required bool showHeadline,
    required bool showSubtitle,
    required bool showSteps,
    required double topInset,
    required double bottomInset,
  }) {
    final brandColor = wide ? Colors.white : AppColors.darkGreen;
    final muted = Colors.white.withValues(alpha: 0.88);

    return Stack(
      fit: StackFit.expand,
      children: [
        const AuthScene(),
        if (wide)
          // One continuous wash: the split pane carries white display type at
          // the foot and a white wordmark at the head, so the scene has to stay
          // dark across its whole height rather than only at the two ends.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.45, 1],
                  colors: [
                    Color(0xE61B5E20),
                    Color(0x991B5E20),
                    Color(0xE60E3A12),
                  ],
                ),
              ),
            ),
          )
        else ...[
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.36],
                  colors: [Color(0xF2EAF5EA), Color(0x00EAF5EA)],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.40, 1],
                  colors: [Color(0x00123415), Color(0xD9123415)],
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? 44 : 18,
            topInset,
            wide ? 44 : 18,
            bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AuthBackButton(
                    onTap: onBack,
                    onDark: wide,
                    tooltip: backTooltip,
                  ),
                  SizedBox(width: wide ? 18 : 12),
                  // Shrinks rather than overflows when the system text size is
                  // turned up on a narrow phone. Expanded, not Flexible, so the
                  // row divides evenly and the pill lands on the right margin.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandLockup(
                        fontSize: wide ? 26 : 20,
                        color: brandColor,
                        letterSpacing: wide ? 1.8 : 1.2,
                      ),
                    ),
                  ),
                  if (wide)
                    const Spacer()
                  else ...[
                    const SizedBox(width: 10),
                    // The badge keeps its natural width and the wordmark gives
                    // up the space: a shrunk brand still reads, a truncated
                    // barangay name does not.
                    const AuthAreaPill(compact: true),
                  ],
                ],
              ),
              const Spacer(),
              if (showHeadline)
                FadeSlideIn(
                  index: 2,
                  offset: 18,
                  child: Text(
                    headline,
                    style: authSans(
                      size: wide ? 40 : 27,
                      weight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: wide ? -1.4 : -0.9,
                      color: Colors.white,
                    ).copyWith(
                      // The scene behind the type is not uniform, so the shadow
                      // carries legibility wherever the wash is thin.
                      shadows: const [
                        Shadow(
                          color: Color(0x59123415),
                          blurRadius: 14,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showSubtitle) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 380 : 320),
                  child: Text(
                    heroSubtitle,
                    style: authSans(
                      size: wide ? 13.5 : 12,
                      weight: FontWeight.w500,
                      height: 1.6,
                      color: muted,
                    ).copyWith(
                      shadows: const [
                        Shadow(
                          color: Color(0x4D123415),
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (wide && showSteps && heroSteps.isNotEmpty) ...[
                const SizedBox(height: 30),
                for (var i = 0; i < heroSteps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _HeroStepRow(index: i + 1, label: heroSteps[i].label),
                ],
              ],
              if (wide) ...[
                const SizedBox(height: 34),
                const AuthAreaPill(onDark: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A numbered line in the wide hero: the step number in a glass square, the
/// instruction beside it.
class _HeroStepRow extends StatelessWidget {
  const _HeroStepRow({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            '$index',
            style: authSans(
              size: 11.5,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: authSans(
              size: 12.5,
              weight: FontWeight.w500,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

/// The rule and label that separate the password form from the social row.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: authSans(
              size: 8.5,
              weight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// "Already have an account? Log in" — the one line that swaps the visitor
/// between the two entry screens.
class AuthAltAction extends StatelessWidget {
  const AuthAltAction({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: authSans(size: 11.5, color: AppColors.inkMuted),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: authSans(size: 11.5, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
