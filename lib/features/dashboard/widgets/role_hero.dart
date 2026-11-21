import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion.dart';

/// One figure on a [RoleHero] summary strip.
class RoleStat {
  const RoleStat({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final int value;

  /// Icon tint. Defaults to a soft mint so every desk reads the same.
  final Color? accent;
}

/// The gradient header every role dashboard opens with.
///
/// One component for residents, the barangay desk, ISWIM, the fleet and City
/// Hall keeps the product recognisable: same radius, same letterhead rings,
/// same eyebrow → greeting → name → purpose rhythm, and the same animated
/// figure strip when the role has counters worth showing.
class RoleHero extends StatelessWidget {
  const RoleHero({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.greeting,
    this.leading,
    this.chip,
    this.stats = const [],
    this.actions = const [],
  });

  /// Small mark beside the eyebrow (a shield, a truck, a person…).
  final IconData icon;

  /// Role and desk, e.g. `CITY HALL · DOCUMENT DESK`.
  final String eyebrow;

  /// The person's name, or the desk name when the role has no single owner.
  final String title;

  /// One line explaining what this dashboard is for.
  final String subtitle;

  /// Time-aware line above the title, e.g. `Good morning`.
  final String? greeting;

  /// Optional avatar shown left of the title block.
  final Widget? leading;

  /// Optional status chip pinned to the eyebrow row.
  final Widget? chip;

  /// Live counters. Keep this to three so they fit a phone.
  final List<RoleStat> stats;

  /// Pills below the counters (address, edit profile…).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(EcoRadius.hero),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDeep.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Two faint rings echo the seal on a government letterhead without
          // competing with the figures the officer reads first.
          const Positioned(
            right: -46,
            top: -62,
            child: RoleHeroRing(size: 186, opacity: 0.08),
          ),
          const Positioned(
            right: 34,
            bottom: -84,
            child: RoleHeroRing(size: 148, opacity: 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    if (chip != null) ...[const SizedBox(width: 8), chip!],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (greeting != null) ...[
                            Text(
                              greeting!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.55,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) const _StatDivider(),
                        Expanded(child: RoleStatFigure(stat: stats[i])),
                      ],
                    ],
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A solid or translucent pill in the hero's eyebrow row.
class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.label,
    required this.icon,
    this.tone,
  });

  final String label;
  final IconData icon;

  /// Solid background when set (amber for pending, green for clear); the
  /// translucent white treatment is used when no tone is given.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final solid = tone != null;
    final foreground = solid ? AppColors.textDark : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone ?? Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline pill used for the hero's secondary actions.
class RoleActionPill extends StatelessWidget {
  const RoleActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The faint letterhead ring behind a gradient header.
///
/// Exposed so sub-screens that reuse the forest gradient (the validation
/// desk summary) carry the same motif instead of drawing their own.
class RoleHeroRing extends StatelessWidget {
  const RoleHeroRing({
    super.key,
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// One animated figure on a gradient header: label, icon and a number that
/// counts up. Shared by [RoleHero] and the validation desk summary.
class RoleStatFigure extends StatelessWidget {
  const RoleStatFigure({super.key, required this.stat});

  final RoleStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              stat.icon,
              size: 12,
              color: stat.accent ?? const Color(0xFFB9F6CA),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                stat.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CountUpText(
          stat.value,
          style: const TextStyle(
            fontSize: 22,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}
