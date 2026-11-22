import 'package:flutter/material.dart';

import '../design/eco_tokens.dart';
import '../theme/app_colors.dart';
import 'eco_page.dart';

/// Section title with an optional trailing action.
///
/// A short brand-green bar anchors the label to the cards underneath, so a
/// long scrolling desk keeps its sections distinguishable at a glance.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: icon == null ? 16 : 20,
          margin: const EdgeInsets.only(top: 2, right: 9),
          decoration: BoxDecoration(
            gradient: AppColors.forestGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: AppColors.darkGreen,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          _HeaderAction(label: actionLabel!, onTap: onAction!),
      ],
    );
  }
}

/// The pill that closes a section header. It warms to mint and nudges its
/// arrow on hover so a section link reads as a control, not a caption.
class _HeaderAction extends StatefulWidget {
  const _HeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.lightGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(EcoRadius.pill),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.sage.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 3),
              AnimatedSlide(
                duration: EcoMotion.fast,
                curve: EcoMotion.enter,
                offset: Offset(_hovered ? 0.35 : 0, 0),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page header used by the staff and resident sub-screens.
///
/// Kept as the name those screens already import; it now renders the shared
/// [EcoPageHeader], so every page that was written against it picks up the
/// same back well, eyebrow slot and typography as the pages using
/// [EcoPageScaffold].
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // The same wash the shared page frame paints, so a screen that keeps its
    // own scaffold still opens with the identical band behind the title.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F3EA), Color(0x00F7FAF7)],
        ),
      ),
      child: EcoPageHeader(
        title: title,
        subtitle: subtitle,
        eyebrow: eyebrow,
        onBack: onBack,
        actions: actions,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      ),
    );
  }
}

/// Small uppercase label that opens a dashboard section.
///
/// Replaces the three hand-rolled copies the dashboards used to carry, so
/// "QUICK ACTIONS" sits at the same weight, tracking and colour everywhere.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        if (action != null && onAction != null)
          _SectionAction(label: action!, onTap: onAction!),
      ],
    );
  }
}

/// The small "Show all" / "Open" link that closes a section header. It warms
/// to the brand green and underlines while the pointer is on it, so a label
/// that is only text still reads as clickable.
class _SectionAction extends StatefulWidget {
  const _SectionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SectionAction> createState() => _SectionActionState();
}

class _SectionActionState extends State<_SectionAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _hovered ? AppColors.darkGreen : AppColors.primary,
              decoration: _hovered ? TextDecoration.underline : null,
              decorationColor: AppColors.primary.withValues(alpha: 0.5),
              decorationThickness: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
