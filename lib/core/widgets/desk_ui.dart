import 'package:flutter/material.dart';

import '../design/eco_tokens.dart';
import '../theme/app_colors.dart';
import 'eco_card.dart';
import 'motion.dart';

/// The small pieces every City Hall desk screen shares.
///
/// The dashboard already reads as one desk: a header, a figure strip, a
/// segmented control and a list of records. The sub-screens used to drop all
/// of that and fall back to a bare AppBar with a centred line of grey text,
/// so opening "Delay reports" felt like leaving the product. These widgets
/// let each queue keep the same rhythm without copying the layout by hand.

/// One figure in a [DeskMetricRow].
class DeskMetric {
  const DeskMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.forest,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  /// Tints the tile so the number the desk must act on leads the row.
  final bool highlight;
}

/// The three-figure strip that opens a desk queue.
class DeskMetricRow extends StatelessWidget {
  const DeskMetricRow({super.key, required this.metrics});

  final List<DeskMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: _MetricTile(metric: metrics[i], index: i),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.index});

  final DeskMetric metric;
  final int index;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      index: index,
      offset: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          color: metric.highlight
              ? metric.accent.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          border: Border.all(
            color: metric.highlight
                ? metric.accent.withValues(alpha: 0.32)
                : AppColors.sage.withValues(alpha: 0.75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metric.icon, size: 14, color: metric.accent),
                const Spacer(),
                Container(
                  height: 5,
                  width: 5,
                  decoration: BoxDecoration(
                    color: metric.accent.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.xs + 1),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EcoType.metricValue(
                context,
                color: metric.highlight ? metric.accent : AppColors.forest,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EcoType.metricLabel(context, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search plus a filter row on one white surface.
///
/// They always apply to the same list, so separating them into two floating
/// strips only made the page look busier than it was.
class DeskFilterPanel extends StatelessWidget {
  const DeskFilterPanel({
    super.key,
    required this.search,
    this.filters,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  final Widget search;
  final Widget? filters;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.lg),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            search,
            if (filters != null) ...[
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: AppColors.sage.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 9),
              filters!,
            ],
          ],
        ),
      ),
    );
  }
}

/// One option in a [DeskSegmented] control.
class DeskSegment<T> {
  const DeskSegment({
    required this.value,
    required this.label,
    this.count,
    this.icon,
  });

  final T value;
  final String label;
  final int? count;
  final IconData? icon;
}

/// The sliding two-or-three way switch the dashboard tabs use.
///
/// A `FilterChip` reads as a toggle bolted onto the page; this reads as the
/// same control the desk already knows, so moving between "Open only" and
/// "All" feels like changing a view rather than turning a filter on.
class DeskSegmented<T> extends StatelessWidget {
  const DeskSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<DeskSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / segments.length;
          final index = segments
              .indexWhere((segment) => segment.value == value)
              .clamp(0, segments.length - 1);

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: EcoMotion.base,
                curve: EcoMotion.enter,
                left: index * width,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.forestGradient,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final segment in segments)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(segment.value),
                        child: _SegmentLabel(
                          segment: segment,
                          selected: segment.value == value,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({required this.segment, required this.selected});

  final DeskSegment<T> segment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.inkMuted;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (segment.icon != null) ...[
            Icon(segment.icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: EcoMotion.fast,
              curve: EcoMotion.enter,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (segment.count != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.pill),
              ),
              child: Text(
                '${segment.count}',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon well, title, optional count and a one-line description.
class DeskSectionHeader extends StatelessWidget {
  const DeskSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.count,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 16, color: AppColors.forest),
        ),
        const SizedBox(width: EcoSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.sectionTitle(
                        context,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(EcoRadius.pill),
                      ),
                      child: Text(
                        '$count',
                        style: EcoType.chip(
                          context,
                          color: AppColors.forest,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.bodySmall(context, color: AppColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// A card with a coloured rail down its leading edge.
///
/// The rail is the status, so a clerk scans the queue by colour before
/// reading a single word. Every desk list uses it, which is why the same
/// request reads the same way on the request desk and in Wave 2.
class DeskRailCard extends StatelessWidget {
  const DeskRailCard({
    super.key,
    required this.railColor,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(17, 13, 13, 13),
  });

  final Color railColor;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: railColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Initials disc used wherever a person is named in a desk list.
class DeskInitialAvatar extends StatelessWidget {
  const DeskInitialAvatar({
    super.key,
    required this.name,
    this.size = 30,
    this.tint,
  });

  final String name;
  final double size;
  final Color? tint;

  static const _palette = [
    Color(0xFF2E7D32),
    Color(0xFF00695C),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
  ];

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color get _color {
    if (tint != null) return tint!;
    final seed = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _palette[seed % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// The "3 reports / Showing 3 of 12" line above every queue.
///
/// It carries the clear-filters escape hatch on the same line, because a
/// filtered queue that looks empty is almost always a filter problem.
class DeskResultLine extends StatelessWidget {
  const DeskResultLine({super.key, required this.label, this.onClear});

  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: EcoType.bodyStrong(context, color: AppColors.inkMuted),
        ),
        const Spacer(),
        if (onClear != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Clear filters',
                style: EcoType.label(context, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }
}

/// The empty state a desk queue shows instead of a blank page.
///
/// A centred line of grey text on a tall phone reads as a broken screen. This
/// panel explains what the queue is for, how a record travels through it, and
/// what the clerk can do next — so an empty desk still looks like a desk.
class DeskEmptyQueue extends StatelessWidget {
  const DeskEmptyQueue({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.steps = const [],
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  final IconData icon;
  final String title;
  final String message;

  /// The three hand-offs a record makes before it leaves this desk.
  final List<String> steps;

  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EcoRadius.xl),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.85)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.7),
                  ),
                ),
                child: Icon(icon, size: 24, color: AppColors.forest),
              ),
              const SizedBox(height: EcoSpace.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: EcoType.panelTitle(context, color: AppColors.darkGreen),
              ),
              const SizedBox(height: EcoSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: EcoType.body(context, color: AppColors.inkMuted),
              ),
              if (steps.isNotEmpty) ...[
                const SizedBox(height: EcoSpace.lg),
                _FlowSteps(steps: steps),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: EcoSpace.lg),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon, size: 16),
                    label: Text(actionLabel!, style: EcoType.action(context)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: EcoSpace.lg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EcoRadius.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT FLOWS',
            style: EcoType.eyebrow(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 9),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 17,
                    width: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.forest : AppColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == 0
                            ? AppColors.forest
                            : AppColors.sage.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: EcoType.micro(
                        context,
                        color: i == 0 ? Colors.white : AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        steps[i],
                        style: EcoType.bodyStrong(
                          context,
                          color: AppColors.textDark,
                        ),
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

/// The whole shape of a desk queue: figures, search, filters, result line,
/// records and pagination.
///
/// Every City Hall queue used to assemble these five pieces by hand, which is
/// why they drifted apart — different gaps, different empty states, a result
/// line that sometimes said "2 documents" above nothing. One shell keeps the
/// rhythm identical from the request desk to Wave 2.
class DeskQueueView extends StatelessWidget {
  const DeskQueueView({
    super.key,
    this.metrics,
    required this.search,
    this.filters,
    this.resultLine,
    required this.empty,
    required this.itemCount,
    required this.itemBuilder,
    this.pagination,
    this.listPadding = const EdgeInsets.fromLTRB(20, 6, 20, 10),
    this.separator = 10,
  });

  final List<DeskMetric>? metrics;
  final Widget search;
  final Widget? filters;
  final Widget? resultLine;

  /// Shown when [itemCount] is zero. Use a [DeskEmptyQueue] so the page keeps
  /// explaining the desk instead of going blank.
  final Widget empty;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget? pagination;
  final EdgeInsets listPadding;
  final double separator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (metrics != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: DeskMetricRow(metrics: metrics!),
          ),
        DeskFilterPanel(search: search, filters: filters),
        if (resultLine != null) ...[
          const SizedBox(height: EcoSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: resultLine!,
          ),
        ],
        const SizedBox(height: EcoSpace.sm),
        Expanded(
          child: itemCount == 0
              ? _EmptyLane(child: empty)
              : ListView.separated(
                  padding: listPadding,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => SizedBox(height: separator),
                  itemBuilder: itemBuilder,
                ),
        ),
        if (pagination != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: pagination!,
          ),
      ],
    );
  }
}

/// Holds an empty panel slightly above centre so it reads as the first thing
/// on the page, not as a hole in the middle of it.
class _EmptyLane extends StatelessWidget {
  const _EmptyLane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 28).clamp(0.0, double.infinity),
            maxWidth: double.infinity,
          ),
          child: Align(alignment: const Alignment(0, -0.35), child: child),
        ),
      ),
    );
  }
}

/// A compact labelled fact used under a card title.
class DeskFact extends StatelessWidget {
  const DeskFact({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.inkMuted,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, height: 1.4, color: color),
          ),
        ),
      ],
    );
  }
}
