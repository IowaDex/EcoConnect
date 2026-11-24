import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tickets/models/trip_ticket.dart';
import '../models/assignment_manual.dart';
import '../services/assignment_manual_service.dart';

/// The approved collection schedule.
///
/// The barangay reads it as a copy of the manual; residents read the routes,
/// the collection days and the start time. Only manuals City Hall has signed
/// are listed, so a pending schedule never leaks to either desk.
class AssignmentScheduleScreen extends StatelessWidget {
  const AssignmentScheduleScreen({super.key, this.staffView = false});

  /// The barangay copy adds the driver and plate, and opens the trip ticket.
  final bool staffView;

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
      onBack: () => ecoBack(context, backRoute),
      body: StreamBuilder<List<AssignmentManual>>(
        stream: AssignmentManualService().watchApproved(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading collection schedule');
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load the schedule',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final manuals = snapshot.data ?? const <AssignmentManual>[];
          if (manuals.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No approved schedule yet',
              message: isResident
                  ? 'Once City Hall approves the collection manual, the days, '
                        'start time and routes appear here.'
                  : 'Schedules appear here after City Hall signs the manual '
                        'Iswim submitted.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              for (var i = 0; i < manuals.length; i++) ...[
                _ScheduleCard(
                  manual: manuals[i],
                  showCrew: !isResident,
                  onOpen: manuals[i].ticketId == null
                      ? null
                      : () => context.push('/tickets/${manuals[i].ticketId}'),
                ),
                if (i < manuals.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.manual,
    required this.showCrew,
    this.onOpen,
  });

  final AssignmentManual manual;
  final bool showCrew;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = manual.allAssignments;
    final title = rows.length > 1
        ? (showCrew
              ? '${rows.length} drivers · ${manual.allRoutes.length} areas'
              : '${manual.allRoutes.length} areas')
        : (manual.routesLabel.isEmpty ? manual.title : manual.routesLabel);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const StatusBadge(
                    label: 'Approved',
                    color: AppColors.primary,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                if (rows.length > 1)
                  Text(
                    '${rows[i].driverName}'
                    '${showCrew ? ' · ${rows[i].plateNumber}' : ''}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreen,
                    ),
                  ),
                if (rows.length > 1) const SizedBox(height: 3),
                _fact(Icons.place_outlined, rows[i].routesLabel),
                const SizedBox(height: 3),
                _fact(
                  Icons.event_repeat_rounded,
                  '${([...rows[i].days]..sort()).map(manualDayLabel).join(', ')}'
                  ' · ${rows[i].startTime} · ${rows[i].recurrence.label}',
                ),
                if (rows.length == 1 && showCrew) ...[
                  const SizedBox(height: 3),
                  _fact(
                    Icons.local_shipping_rounded,
                    '${rows[i].plateNumber} · ${rows[i].wheelers}-wheeler',
                  ),
                  const SizedBox(height: 3),
                  _fact(Icons.person_pin_circle_rounded, rows[i].driverName),
                ],
              ],
              if (manual.approvedAt != null) ...[
                const SizedBox(height: 7),
                Text(
                  'Approved ${timeAgo(manual.approvedAt)}'
                  '${manual.approvedByName == null ? '' : ' by ${manual.approvedByName}'}'
                  ' · valid until ${dateLabel(manual.validUntil)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.moss),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
