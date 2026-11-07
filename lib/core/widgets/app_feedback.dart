import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One place for transient feedback and destructive-action confirmation.
abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.primary, Icons.check_circle_outline_rounded);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.error, Icons.error_outline_rounded);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.darkGreen, Icons.info_outline_rounded);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  /// Returns true only when the user explicitly confirms.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                size: 30,
                color: destructive ? AppColors.error : AppColors.primary,
              ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Human-readable message for Firestore / auth failures.
  static String describe(Object error) {
    final raw = error.toString();
    if (raw.contains('permission-denied') || raw.contains('PERMISSION_DENIED')) {
      return 'You do not have permission to do that. '
          'Ask barangay staff if this keeps happening.';
    }
    if (raw.contains('unavailable') || raw.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    if (raw.contains(']')) return raw.split(']').last.trim();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }
}
