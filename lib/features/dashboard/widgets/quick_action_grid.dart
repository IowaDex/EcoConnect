import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
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

  /// Tile height. 92 fits a centred icon well and a two-line label.
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

/// A single shortcut.
///
/// The tile is centred so it reads as an app shortcut rather than a list row.
/// Hovering lights the icon well with the brand gradient and warms the card,
/// which is the only hover cue the tile needs: [EcoCard] supplies the lift,
/// shadow and border.
class _ActionTile extends StatefulWidget {
  const _ActionTile({required this.action, this.onLocked});

  final QuickAction action;
  final ValueChanged<QuickAction>? onLocked;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  void _setHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final locked = action.locked;
    final interactive = !locked || widget.onLocked != null;
    final lit = _hovered && !locked;

    final VoidCallback? onTap;
    if (locked) {
      onTap = widget.onLocked == null
          ? null
          : () => widget.onLocked!(action);
    } else {
      onTap = () => context.push(action.route);
    }

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: EcoCard(
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        color: lit ? const Color(0xFFF3F9F3) : Colors.white,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: EcoMotion.fast,
                    curve: EcoMotion.enter,
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: lit
                          ? null
                          : (locked ? AppColors.cream : AppColors.mint),
                      gradient: lit ? AppColors.forestGradient : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: AppColors.forest.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      action.icon,
                      size: 17,
                      color: lit
                          ? Colors.white
                          : (locked ? AppColors.inkMuted : AppColors.forest),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: locked ? AppColors.inkMuted : AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: AppColors.inkMuted,
                ),
              )
            else if (action.badge > 0)
              Positioned(right: 0, top: 0, child: _CountBadge(action.badge)),
          ],
        ),
      ),
    );
  }
}

/// The small count in the tile's top-right corner. It pops in the first time
/// the count is above zero, so work arriving while the dashboard is open is
/// noticeable without a full repaint.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: EcoMotion.slow,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
