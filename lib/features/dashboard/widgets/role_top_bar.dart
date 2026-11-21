import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../notifications/widgets/notification_bell.dart';

/// The wordmark, bell and sign-out row every role dashboard opens with.
///
/// Keeping it on the page background (rather than inside the hero) means the
/// gradient header starts at the same place on every role, so switching
/// accounts does not move the page furniture around.
class RoleTopBar extends StatelessWidget {
  const RoleTopBar({super.key, this.onLogout, this.actions = const []});

  /// Hidden when the role signs out from another surface (residents use the
  /// profile sheet).
  final VoidCallback? onLogout;

  /// Extra controls after the bell, e.g. the community composer.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        children: [
          const BrandWordmark(fontSize: 10.5),
          const Spacer(),
          const NotificationBell(iconSize: 19, color: AppColors.inkMuted),
          if (onLogout != null) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Sign out',
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(20),
                hoverColor: AppColors.lightGreen,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ],
          ...actions,
        ],
      ),
    );
  }
}
