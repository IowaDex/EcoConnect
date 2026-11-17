import 'package:flutter/material.dart';

import '../design/eco_tokens.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

/// The app's primary action.
///
/// Presses dip the button slightly, the label cross-fades into a spinner while
/// work is in flight, and the disabled state keeps its colour but loses the
/// pointer — so the control never jumps in size between states.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final child = AnimatedSwitcher(
      duration: EcoMotion.fast,
      switchInCurve: EcoMotion.enter,
      switchOutCurve: EcoMotion.exit,
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? AppColors.forest : Colors.white,
              ),
            )
          : Text(label, key: const ValueKey('label')),
    );

    final button = SizedBox(
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: child,
            )
          : FilledButton(onPressed: enabled ? onPressed : null, child: child),
    );

    return HoverLift(
      enabled: enabled,
      pressedScale: 0.975,
      hoverScale: 1.008,
      lift: 1,
      child: button,
    );
  }
}
