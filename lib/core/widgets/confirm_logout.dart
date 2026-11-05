import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Asks "are you sure?" before signing out. True only if the user confirms.
/// [message] lets a screen add context (e.g. a route still running).
Future<bool> confirmLogout(
  BuildContext context, {
  String message = 'Are you sure you want to logout?',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.creamBright,
      title: const Text('Logout'),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      // Two equal-width buttons side by side.
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed == true;
}
