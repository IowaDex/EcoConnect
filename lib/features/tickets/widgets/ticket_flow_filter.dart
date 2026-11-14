import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/trip_ticket.dart';

/// The stages a trip ticket passes through, from the moment Iswim issues it to
/// the City Hall signature.
///
/// A stage owns one or more raw [TicketStatus] values so the filter row stays
/// short enough to fit on a phone: "With driver" covers a ticket the driver
/// has not accepted yet and one he has to revise, and "Not completed" covers
/// every way a ticket can stop without a City Hall signature.
enum TicketFlowStage {
  withDriver,
  onTheRoad,
  barangay,
  iswim,
  cityHall,
  completed,
  notCompleted,
}

extension TicketFlowStageX on TicketFlowStage {
  String get label => switch (this) {
        TicketFlowStage.withDriver => 'With driver',
        TicketFlowStage.onTheRoad => 'On the road',
        TicketFlowStage.barangay => 'Barangay',
        TicketFlowStage.iswim => 'Your signature',
        TicketFlowStage.cityHall => 'City Hall',
        TicketFlowStage.completed => 'Completed',
        TicketFlowStage.notCompleted => 'Not completed',
      };

  /// One line explaining the stage, used by the empty state.
  String get description => switch (this) {
        TicketFlowStage.withDriver =>
          'Tickets waiting for the driver to accept, start or revise the trip.',
        TicketFlowStage.onTheRoad => 'Tickets whose trip is happening now.',
        TicketFlowStage.barangay =>
          'Tickets waiting for the barangay to verify the trip.',
        TicketFlowStage.iswim => 'Tickets waiting for your signature.',
        TicketFlowStage.cityHall =>
          'Tickets you signed that are waiting for City Hall.',
        TicketFlowStage.completed =>
          'Tickets signed by the driver, barangay, Iswim and City Hall.',
        TicketFlowStage.notCompleted =>
          'Tickets declined, missed, cancelled or rejected before completion.',
      };

  IconData get icon => switch (this) {
        TicketFlowStage.withDriver => Icons.person_outline_rounded,
        TicketFlowStage.onTheRoad => Icons.local_shipping_outlined,
        TicketFlowStage.barangay => Icons.account_balance_outlined,
        TicketFlowStage.iswim => Icons.draw_outlined,
        TicketFlowStage.cityHall => Icons.apartment_rounded,
        TicketFlowStage.completed => Icons.check_circle_outline_rounded,
        TicketFlowStage.notCompleted => Icons.cancel_outlined,
      };

  Color get color => switch (this) {
        TicketFlowStage.withDriver => AppColors.warning,
        TicketFlowStage.onTheRoad => AppColors.moss,
        TicketFlowStage.barangay => AppColors.secondary,
        TicketFlowStage.iswim => AppColors.primary,
        TicketFlowStage.cityHall => AppColors.primary,
        TicketFlowStage.completed => AppColors.primary,
        TicketFlowStage.notCompleted => AppColors.error,
      };

  bool matches(TicketStatus status) => switch (this) {
        TicketFlowStage.withDriver =>
          status == TicketStatus.issued ||
              status == TicketStatus.accepted ||
              status == TicketStatus.revisionRequired,
        TicketFlowStage.onTheRoad => status == TicketStatus.running,
        TicketFlowStage.barangay => status == TicketStatus.submitted,
        TicketFlowStage.iswim => status == TicketStatus.barangaySigned,
        TicketFlowStage.cityHall => status == TicketStatus.iswimSigned,
        TicketFlowStage.completed => status == TicketStatus.completed,
        TicketFlowStage.notCompleted =>
          status == TicketStatus.declined ||
              status == TicketStatus.missed ||
              status == TicketStatus.cancelled ||
              status == TicketStatus.rejected,
      };
}

/// How many tickets sit in each stage. The sum always equals the number of
/// tickets handed in, because every status belongs to exactly one stage.
Map<TicketFlowStage, int> ticketStageCounts(List<TripTicket> tickets) => {
      for (final stage in TicketFlowStage.values)
        stage: tickets.where((ticket) => stage.matches(ticket.status)).length,
    };

/// The tickets in [stage], or every ticket when [stage] is null.
List<TripTicket> ticketsInStage(
  List<TripTicket> tickets,
  TicketFlowStage? stage,
) {
  if (stage == null) return tickets;
  return tickets
      .where((ticket) => stage.matches(ticket.status))
      .toList(growable: false);
}

/// The stage bar above the Iswim ticket list.
///
/// The chips sit in an even grid — two columns on a phone, four once there is
/// room — so every cell is the same width and the rows line up exactly. All
/// eight options are visible at once; nothing scrolls sideways.
class TicketFlowFilterBar extends StatelessWidget {
  const TicketFlowFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.total,
    required this.onChanged,
  });

  /// `null` means All.
  final TicketFlowStage? selected;
  final Map<TicketFlowStage, int> counts;
  final int total;
  final ValueChanged<TicketFlowStage?> onChanged;

  /// Below this width four columns would squeeze the labels, so the grid
  /// stays at two.
  static const _fourColumnBreakpoint = 660.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= _fourColumnBreakpoint ? 4 : 2;
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            _FlowChip(
              width: width,
              label: 'All',
              icon: Icons.grid_view_rounded,
              count: total,
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final stage in TicketFlowStage.values)
              _FlowChip(
                width: width,
                label: stage.label,
                icon: stage.icon,
                accent: stage.color,
                count: counts[stage] ?? 0,
                selected: selected == stage,
                onTap: () => onChanged(stage),
              ),
          ],
        );
      },
    );
  }
}

/// One cell in the stage grid. Filled green when active, white with a soft
/// border otherwise. The label takes the free space and the count sits on the
/// right edge, so counts line up in a column down the bar.
class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.width,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final double width;
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: width,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : AppColors.sage.withValues(alpha: 0.85),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : accent,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
