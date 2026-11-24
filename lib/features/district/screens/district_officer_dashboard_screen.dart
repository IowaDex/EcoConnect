import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../calls/models/call_log.dart';
import '../../calls/providers/call_provider.dart';
import '../../calls/services/call_service.dart';
import '../../dashboard/widgets/quick_action_grid.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../delay/models/delay_report.dart';
import '../../delay/services/delay_service.dart';
import '../../sos/models/sos_incident.dart';
import '../../sos/services/sos_service.dart';

/// The District Officer's coordination desk.
///
/// One job, two calls: answer DSQC about a late truck, then call the barangay
/// with the reason. The history underneath is the reference if the two desks
/// remember the call differently.
class DistrictOfficerDashboardScreen extends StatefulWidget {
  const DistrictOfficerDashboardScreen({super.key});

  @override
  State<DistrictOfficerDashboardScreen> createState() =>
      _DistrictOfficerDashboardScreenState();
}

class _DistrictOfficerDashboardScreenState
    extends State<DistrictOfficerDashboardScreen> {
  late final Stream<List<DelayReport>> _delays;
  late final Stream<List<CallLog>> _calls;
  late final Stream<List<SosIncident>> _sos;

  @override
  void initState() {
    super.initState();
    _delays = DelayService().watchAll();
    final user = context.read<AuthProvider>().currentUser;
    final uid = user?.uid;
    _calls = uid == null
        ? const Stream<List<CallLog>>.empty()
        : CallService().watchHistory(uid);
    _sos = uid == null
        ? const Stream<List<SosIncident>>.empty()
        : SosService().watchForOfficer(uid: uid, district: user?.district);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final calls = context.watch<CallProvider>();
    final name = user?.displayName?.trim();
    final firstName = (name == null || name.isEmpty)
        ? 'Officer'
        : name.split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            RoleTopBar(onLogout: () => confirmAndLogout(context)),
            Expanded(
              child: StreamBuilder<List<SosIncident>>(
                stream: _sos,
                builder: (context, sosSnapshot) {
                  final incidents = sosSnapshot.data ?? const <SosIncident>[];
                  return StreamBuilder<List<DelayReport>>(
                    stream: _delays,
                    builder: (context, delaySnapshot) {
                      final delays =
                          delaySnapshot.data ?? const <DelayReport>[];
                      return StreamBuilder<List<CallLog>>(
                        stream: _calls,
                        builder: (context, callSnapshot) {
                          final logs =
                              callSnapshot.data ?? const <CallLog>[];
                          return _content(
                            firstName: firstName,
                            incidents: incidents,
                            delays: delays,
                            logs: logs,
                            calls: calls,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content({
    required String firstName,
    required List<SosIncident> incidents,
    required List<DelayReport> delays,
    required List<CallLog> logs,
    required CallProvider calls,
  }) {
    final openSos = incidents.where((incident) => incident.isOpen).toList();
    final newAlerts = incidents
        .where((incident) => incident.status == SosStatus.newAlert)
        .length;
    final acknowledged = incidents
        .where((incident) => incident.status == SosStatus.acknowledged)
        .length;
    final coordinating = incidents
        .where((incident) => incident.status == SosStatus.coordinating)
        .length;
    final resolved = incidents
        .where((incident) => incident.status == SosStatus.resolved)
        .length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            RoleHero(
              icon: Icons.support_agent_rounded,
              eyebrow: 'DISTRICT OFFICER · SOS COORDINATION',
              greeting: greeting(),
              title: firstName,
              subtitle:
                  'Read the SOS from DSQC, then call the affected barangay '
                  'with the complete incident so residents are informed.',
              chip: openSos.isNotEmpty
                  ? RoleChip(
                      label: '${openSos.length} active SOS',
                      icon: Icons.sos_rounded,
                      tone: AppColors.error,
                    )
                  : const RoleChip(
                      label: 'No active SOS',
                      icon: Icons.check_circle_rounded,
                    ),
              stats: [
                RoleStat(
                  icon: Icons.priority_high_rounded,
                  label: 'New alerts',
                  value: newAlerts,
                  accent: newAlerts > 0 ? AppColors.error : null,
                ),
                RoleStat(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Acknowledged',
                  value: acknowledged,
                  accent: acknowledged > 0 ? AppColors.warning : null,
                ),
                RoleStat(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Coordinating',
                  value: coordinating,
                ),
                RoleStat(
                  icon: Icons.task_alt_rounded,
                  label: 'Resolved',
                  value: resolved,
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.lg),
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: 'Active SOS alerts',
                    subtitle:
                        'The complete incident is already here — no need to '
                        'call DSQC first.',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/sos'),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.xs),
            if (openSos.isEmpty)
              const _EmptyLine(
                icon: Icons.sos_outlined,
                text: 'No SOS incident is waiting. The line is clear.',
              )
            else
              for (final incident in openSos.take(4)) ...[
                _SosLine(incident: incident),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: EcoSpace.lg),
            const _SectionTitle(
              title: 'Coordination call',
              subtitle:
                  'Calls stay inside EcoConnect. Nothing is dialled on the '
                  'public phone network.',
            ),
            const SizedBox(height: EcoSpace.sm),
            _CallCard(
              icon: Icons.shield_outlined,
              title: 'Call Barangay staff',
              detail:
                  'Open the barangay directory, pick the affected desk, and '
                  'explain the incident and the reported reason.',
              tone: AppColors.forest,
              busy: calls.busy,
              onTap: () => context.push('/district-officer/staff'),
            ),
            const SizedBox(height: EcoSpace.lg),
            const _SectionTitle(
              title: 'Desk shortcuts',
              subtitle: 'Everything the officer needs between calls.',
            ),
            const SizedBox(height: EcoSpace.sm),
            const QuickActionGrid(
              actions: [
                QuickAction(
                  label: 'SOS incidents',
                  icon: Icons.sos_rounded,
                  route: '/sos',
                ),
                QuickAction(
                  label: 'Call history',
                  icon: Icons.history_rounded,
                  route: '/district-officer/calls',
                ),
                QuickAction(
                  label: 'Barangay directory',
                  icon: Icons.contact_phone_rounded,
                  route: '/district-officer/staff',
                ),
                QuickAction(
                  label: 'Delay reports',
                  icon: Icons.timer_outlined,
                  route: '/delays',
                ),
                QuickAction(
                  label: 'Notifications',
                  icon: Icons.notifications_none_rounded,
                  route: '/notifications',
                ),
                QuickAction(
                  label: 'Announcements',
                  icon: Icons.campaign_outlined,
                  route: '/announcements',
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.lg),
            const _SectionTitle(
              title: 'Latest delay reports',
              subtitle: 'Filed by Iswim and pushed down by City Hall.',
            ),
            const SizedBox(height: EcoSpace.sm),
            if (delays.isEmpty)
              const _EmptyLine(
                icon: Icons.timer_off_outlined,
                text: 'No delay report is on the wire.',
              )
            else
              for (final report in delays.take(3)) ...[
                _DelayLine(report: report),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: EcoSpace.md),
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: 'Recent calls',
                    subtitle: 'A shared record written by both phones.',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/district-officer/calls'),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.xs),
            if (logs.isEmpty)
              const _EmptyLine(
                icon: Icons.phone_callback_outlined,
                text: 'No call has been made or answered yet.',
              )
            else
              for (final log in logs.take(3)) ...[
                _RecentCall(log: log, uid: userUid(context)),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  String userUid(BuildContext context) =>
      context.read<AuthProvider>().currentUser?.uid ?? '';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.45,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
    required this.onTap,
    required this.busy,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color tone;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
            border: Border.all(color: AppColors.sage),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: tone),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: tone,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  busy ? Icons.hourglass_top_rounded : Icons.call_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosLine extends StatelessWidget {
  const _SosLine({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final status = incident.status;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/sos/${incident.id}'),
        borderRadius: BorderRadius.circular(EcoRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EcoRadius.md),
            border: Border.all(
              color: status.color.withValues(alpha: 0.55),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(status.icon, size: 17, color: status.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          incident.code,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            status.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: status.color,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo(incident.createdAt),
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      incident.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      incident.location,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DelayLine extends StatelessWidget {
  const _DelayLine({required this.report});

  final DelayReport report;

  @override
  Widget build(BuildContext context) {
    final waiting = report.stage == DelayStage.districtOfficer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(
          color: waiting
              ? AppColors.warning.withValues(alpha: 0.7)
              : AppColors.sage,
        ),
      ),
      child: Row(
        children: [
          Icon(
            waiting ? Icons.phone_in_talk_rounded : Icons.timer_outlined,
            size: 16,
            color: waiting ? AppColors.warning : AppColors.inkMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.code} · ${report.plateNumber}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.reason} · ${report.minutesLate} min late · '
                  '${timeAgo(report.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (waiting)
            const Text(
              'WAITING',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFFB26A00),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentCall extends StatelessWidget {
  const _RecentCall({required this.log, required this.uid});

  final CallLog log;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final outgoing = log.isOutgoing(uid);
    final missed =
        log.outcome == CallOutcome.missed ||
        log.outcome == CallOutcome.declined;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        children: [
          Icon(
            outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
            size: 15,
            color: missed ? AppColors.error : AppColors.forest,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              log.contactFor(uid),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
          Text(
            log.outcome.label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: missed ? AppColors.error : AppColors.inkMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo(log.startedAt),
            style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
