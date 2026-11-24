import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../models/assignment_manual.dart';
import '../services/assignment_manual_service.dart';

/// The month view both desks open with: which crew is on duty, and when.
///
/// Every approved manual is drawn on its days, and a manual still waiting for
/// City Hall is drawn too so the desk can see what is about to join the
/// roster. Tapping a day lists the driver, plate, start time and streets.
class ShiftCalendarCard extends StatefulWidget {
  const ShiftCalendarCard({
    super.key,
    this.showPending = true,
    this.collapsible = false,
  });

  /// Iswim and City Hall see drafts; a resident-facing copy would not.
  final bool showPending;

  /// Opens with the month grid folded away, showing only the crew on the
  /// selected day. A dashboard that puts work first keeps the roster compact
  /// until the officer asks to see the whole month.
  final bool collapsible;

  @override
  State<ShiftCalendarCard> createState() => _ShiftCalendarCardState();
}

class _ShiftCalendarCardState extends State<ShiftCalendarCard> {
  late DateTime _month;
  late DateTime _selected;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
    _selected = DateTime(today.year, today.month, today.day);
    _expanded = !widget.collapsible;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftMonth(int delta) {
    final month = DateTime(_month.year, _month.month + delta);
    setState(() {
      _month = month;
      // Land on the first day of the new month instead of an out-of-range day.
      _selected = DateTime(month.year, month.month, 1);
    });
  }

  void _goToday() {
    final today = DateTime.now();
    setState(() {
      _month = DateTime(today.year, today.month);
      _selected = DateTime(today.year, today.month, today.day);
    });
  }

  List<AssignmentManual> _shiftsOn(
    List<AssignmentManual> manuals,
    DateTime day,
  ) {
    final shifts = manuals
        .where((manual) => widget.showPending || manual.isApproved)
        .where((manual) => manual.runsOn(day))
        .toList();
    shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
    return shifts;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AssignmentManual>>(
      stream: AssignmentManualService().watchAll(),
      builder: (context, snapshot) {
        final manuals = snapshot.data ?? const <AssignmentManual>[];
        final dayShifts = _shiftsOn(manuals, _selected);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('SHIFT CALENDAR'),
            const SizedBox(height: EcoSpace.xs),
            const Text(
              'Who is on duty, and on which day.',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: EcoSpace.sm),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.lg),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.7),
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _monthHeader(manuals),
                  if (_expanded) ...[
                    const SizedBox(height: 6),
                    _weekdayHeader(),
                    const SizedBox(height: 2),
                    ..._monthGrid(manuals),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.sage),
                  const SizedBox(height: 10),
                  _dayHeader(dayShifts.length),
                  const SizedBox(height: 6),
                  if (dayShifts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No crew scheduled on this day.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < dayShifts.length; i++) ...[
                      _ShiftRow(manual: dayShifts[i]),
                      if (i < dayShifts.length - 1)
                        const SizedBox(height: EcoSpace.xs),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _monthHeader(List<AssignmentManual> manuals) {
    final label = '${_monthName(_month.month)} ${_month.year}';
    final count = _shiftsInMonth(manuals);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                count == 1 ? '1 shift this month' : '$count shifts this month',
                style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _goToday,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Today'),
        ),
        _arrow(Icons.chevron_left_rounded, 'Previous month', () {
          _shiftMonth(-1);
        }),
        _arrow(Icons.chevron_right_rounded, 'Next month', () {
          _shiftMonth(1);
        }),
        if (widget.collapsible)
          _arrow(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            _expanded ? 'Hide the month' : 'Show the month',
            () => setState(() => _expanded = !_expanded),
          ),
      ],
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

  Widget _weekdayHeader() {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final name in names)
          Expanded(
            child: Center(
              child: Text(
                name,
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
    );
  }

  List<Widget> _monthGrid(List<AssignmentManual> manuals) {
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
                    return _DayCell(
                      day: day,
                      shifts: _shiftsOn(manuals, day).length,
                      selected: _sameDay(day, _selected),
                      today: _sameDay(day, today),
                      onTap: () => setState(() => _selected = day),
                    );
                  },
                ),
              ),
          ],
        ),
    ];
  }

  Widget _dayHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _dayLabel(_selected),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
        ),
        Text(
          count == 1 ? '1 shift' : '$count shifts',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  int _shiftsInMonth(List<AssignmentManual> manuals) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    var total = 0;
    for (var day = 1; day <= days; day++) {
      total += _shiftsOn(
        manuals,
        DateTime(_month.year, _month.month, day),
      ).length;
    }
    return total;
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

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _monthName(int month) => _monthNames[month - 1];

  static String _dayLabel(DateTime date) =>
      '${_dayNames[date.weekday - 1]}, ${_monthName(date.month)} ${date.day}';
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.shifts,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final int shifts;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : today
        ? AppColors.forest
        : AppColors.textDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 34,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: today && !selected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.6))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected || today
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: color,
              ),
            ),
            if (shifts > 0) ...[
              const SizedBox(height: 2),
              Container(
                height: 3.5,
                width: 3.5 + (shifts.clamp(1, 3) - 1) * 4,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.primary,
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

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.manual});

  final AssignmentManual manual;

  @override
  Widget build(BuildContext context) {
    final pending = !manual.isApproved;
    final ticketId = manual.ticketId;

    return InkWell(
      onTap: ticketId == null || ticketId.isEmpty
          ? null
          : () => context.push('/tickets/$ticketId'),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: BoxDecoration(
          color: pending ? AppColors.cream : AppColors.mintSoft,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: pending
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.sage,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.sage),
              ),
              alignment: Alignment.center,
              child: Text(
                manual.startTime,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          manual.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${manual.plateNumber} · ${manual.routesLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (ticketId != null && ticketId.isNotEmpty)
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}
