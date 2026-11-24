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
    this.items,
    this.disabledIndexes = const {},
    this.askAiLocked = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Dark variant is used when the bar sits on the map sheet.
  final bool dark;

  /// Opens the assistant. When null the bar has no middle button.
  final VoidCallback? onAskAi;

  /// Destinations for the current role. Defaults to the resident layout.
  final List<({IconData icon, String label})>? items;

  /// Items that are shown dimmed with a lock until the account is verified.
  /// They still call [onTap] so the screen can explain why.
  final Set<int> disabledIndexes;

  /// Dims the assistant button while the account is not verified.
  final bool askAiLocked;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.fact_check_rounded, label: 'Requests'),
    (icon: Icons.groups_rounded, label: 'Community'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.cream : AppColors.creamBright;
    final destinations = items ?? _items;

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
          for (var i = 0; i < destinations.length; i++) ...[
            if (onAskAi != null && i == 2) _AskAiSlot(locked: askAiLocked),
            Expanded(
              child: _NavItem(
                icon: destinations[i].icon,
                label: destinations[i].label,
                selected: i == currentIndex,
                disabled: disabledIndexes.contains(i),
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );

    if (onAskAi == null) {
      return _safe(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: bar,
        ),
      );
    }

    // The assistant button breaks out of the pill, so the whole bar gets a
    // taller box and the pill is pinned to its bottom.
    return _safe(
      Padding(
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
                child: Center(
                  child: _AskAiButton(onTap: onAskAi!, locked: askAiLocked),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps the pill clear of the phone's own navigation bar. The Scaffold
  /// places this slot flush with the bottom of the screen, so without the
  /// inset the pill sits under the system gesture bar and its labels read
  /// half-faded on a real device.
  Widget _safe(Widget child) {
    return SafeArea(top: false, child: child);
  }
}

/// Gap in the pill row that the raised button sits above.
class _AskAiSlot extends StatelessWidget {
  const _AskAiSlot({this.locked = false});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            locked ? 'Locked' : 'Ask AI',
            style: TextStyle(
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.forest.withValues(alpha: locked ? 0.4 : 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _AskAiButton extends StatefulWidget {
  const _AskAiButton({required this.onTap, this.locked = false});

  final VoidCallback onTap;
  final bool locked;

  @override
  State<_AskAiButton> createState() => _AskAiButtonState();
}

class _AskAiButtonState extends State<_AskAiButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.08 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: widget.locked ? AppColors.sage : AppColors.forest,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.creamBright, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forest.withValues(
                    alpha: widget.locked
                        ? 0.12
                        : (_hovered ? 0.42 : 0.30),
                  ),
                  blurRadius: _hovered ? 22 : 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              widget.locked ? Icons.lock_outline_rounded : Icons.forum_rounded,
              size: 20,
              color: AppColors.creamBright,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft fade that sits between a scrolling page and the floating nav.
///
/// The page ends exactly where the nav begins, so without this a card or an
/// icon is sliced in half along that edge. With it, the last row dissolves
/// into the background and the pill looks like it floats over the page.
///
/// Place it at the bottom of a [Stack] over the scroll view, and add [height]
/// to that view's bottom padding so the last row can still scroll clear of it.
class NavScrim extends StatelessWidget {
  const NavScrim({super.key, this.color});

  static const height = 34.0;

  /// Background to fade into. Defaults to the page background.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? AppColors.background;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                background.withValues(alpha: 0),
                background.withValues(alpha: 0.85),
                background,
              ],
              stops: const [0, 0.65, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.disabled
        ? AppColors.inkMuted.withValues(alpha: 0.45)
        : (widget.selected || _hovered
              ? AppColors.forest
              : AppColors.inkMuted);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: widget.selected && !widget.disabled
                ? AppColors.mint
                : (_hovered && !widget.disabled
                      ? AppColors.mint.withValues(alpha: 0.45)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: widget.selected && !widget.disabled ? 1.12 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(widget.icon, size: 19, color: color),
                    if (widget.disabled)
                      Positioned(
                        right: -7,
                        top: -4,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 9,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
