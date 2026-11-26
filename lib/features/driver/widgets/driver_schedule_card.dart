import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../tickets/models/trip_ticket.dart';

/// This crew's month at a glance, and the date of their next trip.
///
/// Only the signed-in crew's own manual tickets are drawn, so the calendar is
/// their roster rather than the whole barangay's. A day the manual covers gets
/// a green dot; a day whose manual is still with City Hall gets an amber one,
/// because the trip is not confirmed until the DSQC signs it.
class DriverScheduleCard extends StatefulWidget {
  const DriverScheduleCard({super.key, required this.tickets});

  /// Every ticket held by this crew, as the dashboard already listens for.
  final List<TripTicket> tickets;

  @override
  State<DriverScheduleCard> createState() => _DriverScheduleCardState();
}

class _DriverScheduleCardState extends State<DriverScheduleCard> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A ticket that no longer stands for work on any day.
  static bool _isDead(TripTicket ticket) =>
      ticket.status == TicketStatus.cancelled ||
      ticket.status == TicketStatus.declined ||
      ticket.status == TicketStatus.missed;

  /// The crew's shifts on [day], split by whether City Hall has signed.
  List<TripTicket> _shifts(DateTime day) => [
    for (final ticket in widget.tickets)
      if (ticket.isAssignment && !_isDead(ticket) && ticket.runsOn(day)) ticket,
  ];

  bool _isConfirmed(TripTicket ticket) =>
      !ticket.approvalPending && ticket.status != TicketStatus.issued;

  /// The first confirmed shift from today on, looking two months ahead.
  ({DateTime day, TripTicket ticket})? get _nextTrip {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 60; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final ticket in _shifts(day)) {
        if (_isConfirmed(ticket)) return (day: day, ticket: ticket);
      }
    }
    return null;
  }

  /// A manual exists but City Hall has not signed it yet.
  bool get _waitsForCityHall => widget.tickets.any(
    (ticket) => ticket.isAssignment && ticket.approvalPending && !_isDead(ticket),
  );

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
  }

  /// Opens the day's roster: the routes this crew drives on [day].
  void _openDay(DateTime day, List<TripTicket> shifts) {
    if (shifts.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySheet(day: day, shifts: shifts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextTrip;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 15,
                color: AppColors.moss,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              _arrow(Icons.chevron_left_rounded, 'Previous month', () {
                _shiftMonth(-1);
              }),
              _arrow(Icons.chevron_right_rounded, 'Next month', () {
                _shiftMonth(1);
              }),
              TextButton(
                onPressed: _goToday,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Today'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final name in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      name.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          ..._monthGrid(),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.sage),
          const SizedBox(height: 10),
          _nextTripLine(next),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: AppColors.forest),
    );
  }

  List<Widget> _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - 1; // Monday-first grid
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    return [
      for (var row = 0; row < rows; row++)
        Row(
          children: [
            for (var column = 0; column < 7; column++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final dayNumber = row * 7 + column - lead + 1;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const SizedBox(height: 34);
                    }
                    final day = DateTime(_month.year, _month.month, dayNumber);
                    final shifts = _shifts(day);
                    return _DayCell(
                      day: day,
                      shifts: shifts.length,
                      pending:
                          shifts.isNotEmpty &&
                          shifts.every((ticket) => !_isConfirmed(ticket)),
                      today: _sameDay(day, today),
                      onTap: shifts.isEmpty ? null : () => _openDay(day, shifts),
                    );
                  },
                ),
              ),
          ],
        ),
    ];
  }

  Widget _nextTripLine(({DateTime day, TripTicket ticket})? next) {
    if (next == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 15,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _waitsForCityHall
                      ? 'Next trip · waiting for City Hall'
                      : 'No trip scheduled yet',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _waitsForCityHall
                      ? 'Your manual is with the DSQC. The dates appear here '
                            'once it is signed.'
                      : 'A new manual appears here as soon as Iswim assigns '
                            'one to your truck.',
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final ticket = next.ticket;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.event_available_rounded,
          size: 15,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next trip · ${relativeDay(next.day)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dateLabel(next.day)} · ${ticket.windowStart} · '
                '${ticket.routesLabel}',
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.shifts,
    required this.pending,
    required this.today,
    this.onTap,
  });

  final DateTime day;
  final int shifts;

  /// True when every shift on this day still waits for City Hall.
  final bool pending;
  final bool today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = pending ? AppColors.warning : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: today ? AppColors.mint : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: today
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.55))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: today || shifts > 0
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: today ? AppColors.forest : AppColors.textDark,
              ),
            ),
            if (shifts > 0) ...[
              const SizedBox(height: 2),
              Container(
                height: 3.5,
                width: 3.5 + (shifts.clamp(1, 3) - 1) * 4,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ] else
              const SizedBox(height: 5.5),
          ],
        ),
      ),
    );
  }
}

/// The roster behind one calendar cell: every shift on [day] and the areas it
/// covers. Tapping a shift opens the ticket, where the full manual lives.
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.shifts});

  final DateTime day;
  final List<TripTicket> shifts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 17,
                  color: AppColors.forest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel(day),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
                Text(
                  shifts.length == 1 ? '1 shift' : '${shifts.length} shifts',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: shifts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) =>
                    _ShiftTile(day: day, ticket: shifts[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.day, required this.ticket});

  final DateTime day;
  final TripTicket ticket;

  @override
  Widget build(BuildContext context) {
    final routes = ticket.routesForDay(day.weekday);
    final pending = ticket.approvalPending;

    return Material(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/tickets/${ticket.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ticket.plateNumber,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.windowStart,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: pending
                          ? AppColors.warning.withValues(alpha: 0.16)
                          : AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pending ? 'With City Hall' : 'Confirmed',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: pending
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                routes.isEmpty ? ticket.routesLabel : routes.join(' · '),
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
