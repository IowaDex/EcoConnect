import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating pill navigation bar from the reference design.
///
/// Pass [onAskAi] to get the resident layout: a raised assistant button sits
/// in the middle and the four destinations become Home, Track, Community and
/// Profile. Without it the bar keeps the original four-item shape.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.dark = false,
    this.onAskAi,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Dark variant is used when the bar sits on the map sheet.
  final bool dark;

  /// Opens the assistant. When null the bar has no middle button.
  final VoidCallback? onAskAi;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.local_shipping_rounded, label: 'Track'),
    (icon: Icons.groups_rounded, label: 'Community'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.cream : AppColors.creamBright;

    final bar = Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (onAskAi != null && i == 2) const _AskAiSlot(),
            Expanded(
              child: _NavItem(
                icon: _items[i].icon,
                label: _items[i].label,
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );

    if (onAskAi == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: bar,
      );
    }

    // The assistant button breaks out of the pill, so the whole bar gets a
    // taller box and the pill is pinned to its bottom.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SizedBox(
        height: 78,
        child: Stack(
          children: [
            Positioned(left: 0, right: 0, bottom: 0, child: bar),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _AskAiButton(onTap: onAskAi!)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gap in the pill row that the raised button sits above.
class _AskAiSlot extends StatelessWidget {
  const _AskAiSlot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Ask AI',
            style: TextStyle(
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.forest.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _AskAiButton extends StatelessWidget {
  const _AskAiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppColors.forest,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.creamBright, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(
          Icons.forum_rounded,
          size: 20,
          color: AppColors.creamBright,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : AppColors.inkMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
