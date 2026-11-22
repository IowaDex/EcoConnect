import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Social sign-in is not wired yet, so every social control says so instead of
/// pretending to start an OAuth flow.
void _comingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Social sign-in is coming soon')),
    );
}

/// A round social sign-in button (Google, Facebook).
///
/// Used where several providers sit side by side, as on the sign-up screen.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.mark,
    required this.tooltip,
  });

  final Widget mark;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _comingSoon(context),
        customBorder: const CircleBorder(),
        child: Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppColors.creamBright,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.sage),
          ),
          // The Google mark is a square tile; the clip keeps it a round badge
          // that matches the Facebook icon beside it.
          clipBehavior: Clip.antiAlias,
          child: Center(child: mark),
        ),
      ),
    );
  }
}

/// A full-width social sign-in button.
///
/// A lone circle is easy to miss at the bottom of a form, so the login screen
/// uses this instead: the mark plus a written label, in the same shape as every
/// other control on the page.
class SocialWideButton extends StatelessWidget {
  const SocialWideButton({
    super.key,
    required this.mark,
    required this.label,
    required this.tooltip,
  });

  final Widget mark;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: () => _comingSoon(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            side: BorderSide(color: AppColors.sage.withValues(alpha: 0.9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Any mark — image tile or icon — is fitted to the same 20px box
              // so the two providers line up on every screen.
              SizedBox.square(
                dimension: 20,
                child: FittedBox(fit: BoxFit.contain, child: mark),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Google mark shared by the auth screens.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 34});

  /// The tile is square, so the same value drives both edges.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_icon.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
