import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tickets/models/trip_ticket.dart';
import '../models/assignment_manual.dart';
import '../models/manual_assignment.dart';
import '../services/assignment_manual_service.dart';

/// The approved collection schedule.
///
/// The barangay reads it as a copy of the manual; residents read the routes,
/// the collection days and the start time. Only manuals City Hall has signed
/// are listed, so a pending schedule never leaks to either desk.
///
/// One row per crew, not one card per manual: a manual can put three trucks on
/// three different areas, and "when is the truck on my street?" is answered by
/// the crew row, not by the bundle it arrived in.
class AssignmentScheduleScreen extends StatefulWidget {
  const AssignmentScheduleScreen({super.key});

  @override
  State<AssignmentScheduleScreen> createState() =>
      _AssignmentScheduleScreenState();
}

class _AssignmentScheduleScreenState extends State<AssignmentScheduleScreen> {
  final _search = TextEditingController();

  String _query = '';

  /// `null` means every day. Otherwise a weekday, 1 = Monday … 7 = Sunday.
  int? _day;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _day = null;
    });
  }

  bool get _filtered => _query.trim().isNotEmpty || _day != null;

  bool _matches(_ScheduleEntry entry) {
    if (_day != null && !entry.assignment.days.contains(_day)) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return entry.assignment.driverName.toLowerCase().contains(query) ||
        entry.assignment.plateNumber.toLowerCase().contains(query) ||
        entry.assignment.routes.any(
          (area) => area.toLowerCase().contains(query),
        ) ||
        entry.manual.title.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isResident = user?.role == UserRole.user;
    final backRoute = switch (user?.role) {
      UserRole.admin => '/admin-dashboard',
      UserRole.iswim => '/iswim',
      UserRole.cityHall => '/cityhall',
      UserRole.driver => '/driver',
      _ => '/user',
    };

    return EcoPageScaffold(
      eyebrow: isResident ? 'COLLECTION SCHEDULE' : 'BARANGAY · SCHEDULE COPY',
      title: isResident ? 'Collection schedule' : 'Approved schedules',
      subtitle: isResident
          ? 'When the truck reaches your streets, and at what time.'
          : 'The manuals City Hall has approved. This is the barangay copy.',
      icon: Icons.event_available_rounded,
      onBack: () => ecoBack(context, backRoute),
      body: StreamBuilder<List<AssignmentManual>>(
        stream: AssignmentManualService().watchApproved(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading collection schedule');
          }
          if (snapshot.hasError) {
            return DeskEmptyQueue(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load the schedule',
              message: AppFeedback.describe(snapshot.error!),
            );
          }

          final manuals = snapshot.data ?? const <AssignmentManual>[];
          if (manuals.isEmpty) {
            return DeskEmptyQueue(
              icon: Icons.event_busy_outlined,
              title: 'No approved schedule yet',
              message: isResident
                  ? 'Once City Hall approves the collection manual, the days, '
                        'start time and routes appear here.'
                  : 'Schedules appear here after City Hall signs the manual '
                        'Iswim submitted.',
              steps: const [
                'Iswim builds the collection manual',
                'City Hall signs it',
                'The schedule opens here for the barangay',
              ],
            );
          }

          final entries = _entries(manuals);
          final days = <int>{
            for (final e in entries) ...e.assignment.days,
          }.toList()..sort();
          final visible = entries.where(_matches).toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: DeskMetricRow(
                  metrics: isResident
                      ? [
                          DeskMetric(
                            icon: Icons.place_outlined,
                            label: 'Areas',
                            value: '${_areas(entries).length}',
                          ),
                          DeskMetric(
                            icon: Icons.event_repeat_rounded,
                            label: 'Days',
                            value: '${days.length}',
                          ),
                          DeskMetric(
                            icon: Icons.local_shipping_outlined,
                            label: 'Next pickup',
                            value: _nextDayLabel(days),
                            accent: AppColors.warning,
                            highlight: true,
                          ),
                        ]
                      : [
                          DeskMetric(
                            icon: Icons.groups_2_outlined,
                            label: 'Drivers',
                            value: '${entries.length}',
                          ),
                          DeskMetric(
                            icon: Icons.local_shipping_outlined,
                            label: 'Trucks',
                            value: '${_trucks(entries)}',
                          ),
                          DeskMetric(
                            icon: Icons.place_outlined,
                            label: 'Areas',
                            value: '${_areas(entries).length}',
                          ),
                        ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: EcoSearchField(
                  controller: _search,
                  hint: isResident
                      ? 'Search your area'
                      : 'Search driver, plate or area',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _DayBar(
                  days: days,
                  selected: _day,
                  onChanged: (day) => setState(() => _day = day),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: DeskResultLine(
                  label: _resultLabel(visible.length, entries.length),
                  onClear: _filtered ? _clear : null,
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? DeskEmptyQueue(
                        icon: Icons.search_off_rounded,
                        title: 'No schedule matches',
                        message: _day == null
                            ? 'Nothing in this schedule mentions '
                                  '"${_query.trim()}". Try a shorter word or '
                                  'an area name.'
                            : 'No crew runs on ${manualDayLabel(_day!)}. '
                                  'Pick another day or clear the filters.',
                        actionLabel: 'Clear filters',
                        actionIcon: Icons.filter_alt_off_outlined,
                        onAction: _clear,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: EcoSpace.sm),
                        itemBuilder: (context, i) => FadeSlideIn(
                          index: i > 6 ? 6 : i,
                          offset: 10,
                          child: _ScheduleCard(
                            entry: visible[i],
                            showCrew: !isResident,
                            highlightDay: _day,
                            onOpen: () => _openSchedule(
                              context,
                              visible[i],
                              isResident: isResident,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens a crew row.
  ///
  /// The barangay desk gets the crew's trip ticket, because the ticket is the
  /// document it files. A resident has no route to `/tickets` — the router
  /// refuses it for that role — so pushing one sent them straight back to the
  /// dashboard, which made every schedule card look broken. Residents read the
  /// schedule itself instead.
  void _openSchedule(
    BuildContext context,
    _ScheduleEntry entry, {
    required bool isResident,
  }) {
    final route = scheduleTicketRoute(
      isResident: isResident,
      ticketId: entry.ticketId,
    );
    if (route != null) {
      context.push(route);
      return;
    }
    _showScheduleSheet(context, entry);
  }

  void _showScheduleSheet(BuildContext context, _ScheduleEntry entry) {
    final assignment = entry.assignment;
    final days = [...assignment.days]..sort();
    final approved = entry.manual.approvedAt;
    final approver = entry.manual.approvedByName;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamBright,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          children: [
            // The theme's bottomSheetTheme already draws the drag handle.
            Text(
              'COLLECTION SCHEDULE',
              style: EcoType.eyebrow(context, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              assignment.routesLabel.isEmpty
                  ? entry.manual.title
                  : assignment.routesLabel,
              style: EcoType.panelTitle(context, color: AppColors.darkGreen),
            ),
            const SizedBox(height: EcoSpace.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final day in days)
                  _DayPill(day: day, active: day == DateTime.now().weekday),
                _TimePill(
                  label:
                      '${assignment.startTime} · ${assignment.recurrence.label}',
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.lg),
            _SheetFact(
              icon: Icons.event_repeat_rounded,
              label: 'Collection days',
              value: days.map(manualDayLabel).join(', '),
            ),
            _SheetFact(
              icon: Icons.schedule_rounded,
              label: 'Starts at',
              value: assignment.startTime,
            ),
            _SheetFact(
              icon: Icons.autorenew_rounded,
              label: 'Repeats',
              value: assignment.recurrence.label,
            ),
            if (assignment.routes.isNotEmpty)
              _SheetFact(
                icon: Icons.place_outlined,
                label: assignment.routes.length == 1 ? 'Street' : 'Streets',
                value: assignment.routes.join(' · '),
                maxLines: 4,
              ),
            if (approved != null) ...[
              _SheetFact(
                icon: Icons.verified_outlined,
                label: 'Approved',
                value:
                    '${timeAgo(approved)}${approver == null ? '' : ' by $approver'}',
              ),
              _SheetFact(
                icon: Icons.event_available_outlined,
                label: 'Valid until',
                value: dateLabel(entry.manual.validUntil),
              ),
            ],
            const SizedBox(height: EcoSpace.lg),
            PrimaryButton(
              label: 'Open the truck map',
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push('/tracking');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Flattens the manuals into one row per crew, keeping the roster order.
  static List<_ScheduleEntry> _entries(List<AssignmentManual> manuals) {
    final entries = <_ScheduleEntry>[];
    for (final manual in manuals) {
      final rows = manual.allAssignments;
      for (var i = 0; i < rows.length; i++) {
        entries.add(
          _ScheduleEntry(
            manual: manual,
            assignment: rows[i],
            isFirst: i == 0,
            ticketId: i < manual.ticketIds.length
                ? manual.ticketIds[i]
                : manual.ticketId,
          ),
        );
      }
    }
    return entries;
  }

  static Set<String> _areas(List<_ScheduleEntry> entries) => {
    for (final entry in entries) ...entry.assignment.routes,
  };

  static int _trucks(List<_ScheduleEntry> entries) => {
    for (final entry in entries)
      if (entry.assignment.plateNumber.isNotEmpty) entry.assignment.plateNumber,
  }.length;

  /// The next weekday the crew comes, wrapping to the start of the week.
  static String _nextDayLabel(List<int> days) {
    if (days.isEmpty) return '—';
    final today = DateTime.now().weekday;
    final upcoming = days.where((day) => day >= today);
    return manualDayLabel(upcoming.isNotEmpty ? upcoming.first : days.first);
  }

  String _resultLabel(int visible, int total) {
    if (_filtered) return 'Showing $visible of $total';
    return '$total ${total == 1 ? 'crew' : 'crews'}';
  }
}

/// Where a tapped crew row goes, or null when it should open the schedule
/// detail sheet instead.
///
/// Split out so the rule can be tested without Firestore. A resident must
/// never receive a ticket path: `/tickets` is not one of the resident routes,
/// so the router redirected it straight back to the dashboard — which is why
/// every schedule card used to look clickable and then do nothing.
@visibleForTesting
String? scheduleTicketRoute({
  required bool isResident,
  required String? ticketId,
}) {
  if (isResident || ticketId == null) return null;
  return '/tickets/$ticketId';
}

/// One crew row, flattened out of the manual it belongs to.
class _ScheduleEntry {
  const _ScheduleEntry({
    required this.manual,
    required this.assignment,
    required this.isFirst,
    this.ticketId,
  });

  final AssignmentManual manual;
  final ManualAssignment assignment;

  /// The first crew of its manual. Only that card names who approved the
  /// manual, so a three-truck roster does not repeat the same line three times.
  final bool isFirst;

  final String? ticketId;
}

/// Every weekday the schedule uses, plus All, in one fixed row.
///
/// A scrolling strip cut the last chip ("Sat") at the screen edge, which reads
/// as an overlap. Equal cells always fit, so the whole week stays visible.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.days,
    required this.selected,
    required this.onChanged,
  });

  final List<int> days;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    return DeskSegmented<int?>(
      value: selected,
      onChanged: onChanged,
      segments: [
        const DeskSegment<int?>(value: null, label: 'All'),
        for (final day in days)
          DeskSegment<int?>(value: day, label: manualDayLabel(day)),
      ],
    );
  }
}

/// One crew's run: the days, the start time, the areas and — for the barangay
/// copy — the driver and the plate. Tapping opens that crew's trip ticket at
/// the desk, and the schedule detail for a resident.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.entry,
    required this.showCrew,
    required this.highlightDay,
    this.onOpen,
  });

  final _ScheduleEntry entry;
  final bool showCrew;

  /// The day the desk filtered on, so the matching day chip stands out.
  final int? highlightDay;

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final assignment = entry.assignment;
    final days = [...assignment.days]..sort();
    final areas = assignment.routesLabel;

    return DeskRailCard(
      railColor: AppColors.primary,
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final day in days)
                _DayPill(day: day, active: day == highlightDay),
              const SizedBox(width: 3),
              _TimePill(
                label:
                    '${assignment.startTime} · ${assignment.recurrence.label}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            areas.isEmpty ? entry.manual.title : areas,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          if (showCrew) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                DeskInitialAvatar(name: assignment.driverName, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${assignment.driverName}'
                    '${assignment.plateNumber.isEmpty ? '' : ' · ${assignment.plateNumber}'}'
                    ' · ${assignment.wheelers}-wheeler',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
          ],
          if (entry.isFirst) ...[
            const SizedBox(height: 2),
            Text(
              'Valid until ${dateLabel(entry.manual.validUntil)}',
              style: EcoType.meta(
                context,
                color: AppColors.moss,
                weight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              if (entry.isFirst) ...[
                const Icon(
                  Icons.verified_outlined,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.manual.approvedAt == null
                        ? 'Approved by City Hall'
                        : 'Approved ${timeAgo(entry.manual.approvedAt)}'
                              '${entry.manual.approvedByName == null ? '' : ' by ${entry.manual.approvedByName}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                ),
              ] else
                const Spacer(),
              if (onOpen != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.inkMuted,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled line inside the schedule sheet: what it is, then the answer.
class _SheetFact extends StatelessWidget {
  const _SheetFact({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: EcoType.meta(context, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: EcoType.bodyStrong(context, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// A weekday badge. The filtered day is filled so the list reads as the answer
/// to the chip the clerk tapped.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.active});

  final int day;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final isToday = day == today;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.forest : AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(
          color: active
              ? AppColors.forest
              : isToday
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.sage,
        ),
      ),
      child: Text(
        manualDayLabel(day).toUpperCase(),
        style: EcoType.chip(
          context,
          color: active ? Colors.white : AppColors.forest,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The start time and how long the roster stays in force.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 11, color: AppColors.moss),
          const SizedBox(width: 4),
          Text(label, style: EcoType.chip(context, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
