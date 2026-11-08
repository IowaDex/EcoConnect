import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Covers the app with a notice when another device signs in to this account.
/// The user is not signed out until they tap Continue, so they have time to
/// read it; Continue signs out and the router returns to the login page.
class SessionEndedHost extends StatelessWidget {
  const SessionEndedHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Stack(
      children: [
        child,
        if (auth.sessionReplaced) ...[
          const ModalBarrier(color: Colors.black54, dismissible: false),
          Center(
            child: Material(
              color: AppColors.creamBright,
              borderRadius: BorderRadius.circular(22),
              elevation: 6,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.devices_other_rounded,
                          size: 34, color: AppColors.forest),
                      const SizedBox(height: 12),
                      const Text(
                        'Signed in on another device',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your account was just signed in on another device, so '
                        'this session has ended. Tap Continue to go back to the '
                        'login page.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: auth.continueAfterSessionReplaced,
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
