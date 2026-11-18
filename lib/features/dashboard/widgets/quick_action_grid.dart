import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/eco_card.dart';

/// One destination in a [QuickActionGrid].
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    this.badge = 0,
    this.locked = false,
    this.lockedNote = '',
  });

  final String label;
  final IconData icon;
  final String route;

  /// Red count bubble. Zero hides it.
  final int badge;

  /// Shown dimmed with a lock while the account is not verified. Tapping it
  /// calls [QuickActionGrid.onLocked] instead of opening [route].
  final bool locked;

  /// What the resident came here to do, phrased to follow "before you can…":
  /// `'file a complaint'`, `'upload waste photos'`. The lock message names it
  /// so the explanation matches the tile that was tapped.
  final String lockedNote;
}

/// The shortcut grid shared by every role dashboard.
///
/// Two columns on a phone, three or four on a tablet and five on a wide
/// window. The grid is sized by its children and never scrolls on its own, so
/// the page stays the only scrollable and nothing swipes sideways.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.actions,
    this.onLocked,
    this.maxExtent = 210,
    this.extent = 92,
  });

  final List<QuickAction> actions;

  /// Explains why a locked tile cannot be opened. Receives the tapped tile so
  /// the message can name the feature. Without it a locked tile is inert.
  final ValueChanged<QuickAction>? onLocked;

  /// Widest a tile may get before another column is added.
  final double maxExtent;

  /// Tile height. 92 fits a 30 px icon well and a two-line label.
  final double extent;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        mainAxisExtent: extent,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) =>
          _ActionTile(action: actions[index], onLocked: onLocked),
    );
  }
}

/// A single shortcut. [EcoCard] supplies the surface, radius, border and tap
/// feedback so a shortcut looks like every other panel in the app.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, this.onLocked});

  final QuickAction action;
  final ValueChanged<QuickAction>? onLocked;

  @override
  Widget build(BuildContext context) {
    final locked = action.locked;
    final VoidCallback? onTap;
    if (locked) {
      onTap = onLocked == null ? null : () => onLocked!(action);
    } else {
      onTap = () => context.push(action.route);
    }
    return EcoCard(
      padding: const EdgeInsets.all(11),
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: locked ? AppColors.cream : AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    action.icon,
                    size: 16,
                    color: locked ? AppColors.inkMuted : AppColors.forest,
                  ),
                ),
                const Spacer(),
                if (locked)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: AppColors.inkMuted,
                  )
                else if (action.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${action.badge}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.north_east_rounded,
                    size: 11,
                    color: AppColors.sage,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              action.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
