import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'hex_leaf_logo.dart';

/// "Ec⬡Connect" — the brand's O is the hex-leaf mark itself.
///
/// The mark is laid out as a [WidgetSpan] on the alphabetic baseline so it
/// reads as a capital letter sitting in the word, rather than a badge floating
/// between two words.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 15,
    this.color = AppColors.forest,
    this.letterSpacing = 0.6,
  });

  final double fontSize;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return _BrandLine(
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

/// Larger, wider-tracked version of the same wordmark used on the splash and
/// login heroes.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.fontSize = 34,
    this.color = AppColors.forest,
    this.letterSpacing = 2.0,
  });

  final double fontSize;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return BrandWordmark(
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class _BrandLine extends StatelessWidget {
  const _BrandLine({
    required this.fontSize,
    required this.color,
    required this.letterSpacing,
  });

  final double fontSize;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    // A hexagon of side-to-side height 0.92 * size therefore lands on the cap
    // height of the surrounding text, with a hair of overshoot like a real O.
    final markSize = fontSize * 0.86;

    // Letter-spacing is added after the "c", so the left gap already carries
    // some of it. Subtract it to keep the mark optically centred in the word.
    final gap = fontSize * 0.07;
    final leftGap = math.max(0.0, gap - letterSpacing);

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: letterSpacing,
          color: color,
          height: 1,
        ),
        children: [
          const TextSpan(text: 'Ec'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: EdgeInsets.only(left: leftGap, right: gap),
              child: Transform.translate(
                // Nudge below the baseline so the round mark sits optically
                // level with the neighbouring capitals.
                offset: Offset(0, fontSize * 0.02),
                child: HexLeafLogo(
                  size: markSize,
                  color: color,
                  strokeWidth: markSize * 0.11,
                ),
              ),
            ),
          ),
          const TextSpan(text: 'Connect'),
        ],
      ),
    );
  }
}
