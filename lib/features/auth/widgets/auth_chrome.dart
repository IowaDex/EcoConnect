import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
          Text(
            compact ? 'Batasan Hills' : 'Barangay Batasan Hills · Quezon City',
            style: authSans(
              size: 10.5,
              weight: FontWeight.w700,
              letterSpacing: 0.2,
              color: foreground,
            ),
          ),
        ],
      ),
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
