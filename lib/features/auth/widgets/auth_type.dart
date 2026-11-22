import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// The face used by the entry screens.
///
/// The dashboards keep Poppins for prose, but login and sign-up are almost all
/// control surface — headings, labels, buttons, links. Setting the whole flow
/// in one grotesque (the face already used for button labels) makes the two
/// screens read as one instrument instead of two type systems meeting at the
/// fold.
TextStyle authSans({
  required double size,
  FontWeight weight = FontWeight.w400,
  double? height,
  double? letterSpacing,
  Color? color,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}

/// The small tracked line above an auth heading, e.g. `ACCOUNT ACCESS`.
class AuthEyebrow extends StatelessWidget {
  const AuthEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 6,
          width: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: authSans(
            size: 9,
            weight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// The title block both entry screens open with.
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthEyebrow(eyebrow),
        const SizedBox(height: 12),
        Text(
          title,
          style: authSans(
            size: 28,
            weight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -0.9,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: authSans(size: 12, height: 1.55, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
