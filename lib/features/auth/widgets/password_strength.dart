import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/validators.dart';

/// Live password checklist shown while an account is being created.
///
/// The same [Validators.passwordChecks] list drives validation, so a rule
/// can never be shown as satisfied while the form still rejects the value.
class PasswordStrengthChecklist extends StatelessWidget {
  const PasswordStrengthChecklist({
    super.key,
    required this.password,
    this.compact = false,
  });

  final String password;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final checks = Validators.passwordChecks(password);
    final met = checks.where((c) => c.met).length;
    final progress = met / checks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.sage.withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1 ? AppColors.primary : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            for (final check in checks)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    check.met
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 12,
                    color: check.met ? AppColors.primary : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    check.label,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.3,
                      fontWeight: check.met ? FontWeight.w600 : FontWeight.w400,
                      color: check.met ? AppColors.primary : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
