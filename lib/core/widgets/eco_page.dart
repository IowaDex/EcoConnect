import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/eco_tokens.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

/// Goes back when there is a page to go back to, otherwise lands on the
/// role's home. Every sub-screen used to repeat this ternary with its own
/// hard-coded home route; the fallback is now an explicit argument so the
/// behaviour is visible at the call site.
void ecoBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// The page frame every desk, queue and detail screen shares.
///
/// One frame means a page opened from the barangay desk looks like a page
/// opened from City Hall, ISWIM or the driver console: the same soft green
/// wash behind the header, the same back affordance, the same 980px content
/// column on a desktop window and the same 20px gutter on a phone.
///
/// Pass [children] for the usual scrolling page. Pass [body] instead when the
/// page owns its own scroll view (tabs, a map, a two-pane split).
class EcoPageScaffold extends StatelessWidget {
  const EcoPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
    this.onBack,
    this.actions = const [],
    this.children = const [],
    this.body,
    this.bottomBar,
    this.fab,
    this.maxWidth = 980,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 28),
    this.background = AppColors.background,
  });

  final String title;
  final String? subtitle;

  /// Small uppercase line above the title, e.g. `BARANGAY STAFF · DESK`.
  final String? eyebrow;

  /// Mark shown left of the title block.
  final IconData? icon;

  final VoidCallback? onBack;

  /// Trailing controls in the header row (search, filter, add…).
  final List<Widget> actions;

  /// Scrolling content. Ignored when [body] is given.
  final List<Widget> children;

  /// Non-scrolling content that fills the page.
  final Widget? body;

  final Widget? bottomBar;
  final Widget? fab;
  final double maxWidth;
  final EdgeInsets padding;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final content = body ??
        ListView(
          padding: padding,
          children: [
            for (var i = 0; i < children.length; i++)
              FadeSlideIn(index: i, child: children[i]),
          ],
        );

    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: bottomBar,
      floatingActionButton: fab,
      body: Stack(
        children: [
          // The wash sits behind the header and fades into the page, so the
          // title area reads as a band without a hard edge anywhere.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(child: _HeaderWash()),
          ),
          SafeArea(
            bottom: bottomBar == null,
            child: Column(
              children: [
                EcoPageHeader(
                  title: title,
                  subtitle: subtitle,
                  eyebrow: eyebrow,
                  icon: icon,
                  onBack: onBack,
                  actions: actions,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 180px gradient band behind a page header.
class _HeaderWash extends StatelessWidget {
  const _HeaderWash();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE6F2E7), Color(0x00F7FAF7)],
        ),
      ),
    );
  }
}

/// The header used by [EcoPageScaffold] and by pages that keep their own
/// scaffold (the dashboards, which carry a role top bar above the content).
///
/// Left to right: back well, optional mark, eyebrow + title + subtitle, then
/// the page's own actions. The back well is a real 36px target with a hover
/// wash, because a bare arrow icon is easy to miss on a desktop window.
class EcoPageHeader extends StatelessWidget {
  const EcoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 14),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData? icon;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            EcoBackWell(onTap: onBack!),
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            _MarkWell(icon: icon!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.darkGreen,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The rounded back target in every page header.
class EcoBackWell extends StatefulWidget {
  const EcoBackWell({super.key, required this.onTap, this.tooltip = 'Back'});

  final VoidCallback onTap;
  final String tooltip;

  @override
  State<EcoBackWell> createState() => _EcoBackWellState();
}

class _EcoBackWellState extends State<EcoBackWell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: EcoMotion.fast,
            curve: EcoMotion.enter,
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.lightGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.sage.withValues(alpha: 0.8),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AppColors.darkGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// A brand-tinted icon well, used when a page has no back affordance.
class _MarkWell extends StatelessWidget {
  const _MarkWell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 17, color: Colors.white),
    );
  }
}

/// A header-sized icon button with the same hover wash as [EcoBackWell].
class EcoIconAction extends StatefulWidget {
  const EcoIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color = AppColors.darkGreen,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color color;

  @override
  State<EcoIconAction> createState() => _EcoIconActionState();
}

class _EcoIconActionState extends State<EcoIconAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? AppColors.lightGreen
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered && enabled
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.sage.withValues(alpha: 0.7),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 17,
            color: enabled
                ? widget.color
                : widget.color.withValues(alpha: 0.35),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
