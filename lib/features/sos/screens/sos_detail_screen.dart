import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calls/models/call_log.dart';
import '../../calls/services/call_service.dart';
import '../models/sos_incident.dart';
import '../services/sos_service.dart';

/// The full incident a District Officer opens from the alert or the push.
///
/// Everything DSQC entered is on this page; the officer never has to call
/// DSQC to ask what happened before ringing the barangay.
class SosDetailScreen extends StatefulWidget {
  const SosDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  State<SosDetailScreen> createState() => _SosDetailScreenState();
}

class _SosDetailScreenState extends State<SosDetailScreen> {
  bool _acknowledged = false;
  bool _updating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_acknowledged) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.role != UserRole.districtOfficer) return;
    _acknowledged = true;
    // Opening the incident is the acknowledgement: no extra button.
    SosService()
        .markAcknowledged(
          widget.incidentId,
          uid: user.uid,
          name: user.displayName ?? 'District Officer',
        )
        .catchError((Object _) {});
  }

  /// Closes the incident. The note is optional, the confirmation is not: a
  /// resolved incident is the end of the line for this record.
  Future<void> _resolve(SosIncident incident) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ResolveDialog(incident: incident),
    );
    if (note == null || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _updating) return;
    setState(() => _updating = true);
    try {
      await SosService().resolve(
        incident.id,
        uid: user.uid,
        name: user.displayName ?? 'District Officer',
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Incident resolved'),
            backgroundColor: AppColors.forest,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not resolve the incident: $error'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _contactBarangay(SosIncident incident) {
    final query = Uri(
      queryParameters: {
        'barangay': incident.barangay,
        'incidentId': incident.id,
        'code': incident.code,
        'reason': incident.reason,
      },
    ).query;
    context.push('/district-officer/staff?$query');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final role = user?.role ?? UserRole.user;
    final officer = role == UserRole.districtOfficer;

    return EcoPageScaffold(
      eyebrow: officer
          ? 'DISTRICT OFFICER · SOS INCIDENT'
          : 'SOS INCIDENT · MONITORING',
      title: 'Incident details',
      subtitle:
          'The record DSQC sent, the coordination status, and every call '
          'made about it.',
      icon: Icons.sos_rounded,
      onBack: () => ecoBack(
        context,
        officer ? '/district-officer' : '/sos',
      ),
      body: StreamBuilder<SosIncident?>(
        stream: SosService().watchOne(widget.incidentId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load the incident.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forest,
                strokeWidth: 2,
              ),
            );
          }
          final incident = snapshot.data;
          if (incident == null) {
            return const _Message(
              icon: Icons.search_off_rounded,
              text: 'This incident no longer exists.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _Header(incident: incident),
              const SizedBox(height: 12),
              _Details(incident: incident),
              if (officer) ...[
                const SizedBox(height: 12),
                _Coordination(
                  incident: incident,
                  updating: _updating,
                  onContact: () => _contactBarangay(incident),
                  onResolve: () => _resolve(incident),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _MonitorNote(incident: incident),
              ],
              const SizedBox(height: 12),
              _Timeline(incident: incident),
              const SizedBox(height: 12),
              _IncidentCalls(incident: incident),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final status = incident.status;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(status.icon, size: 21, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.code,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sent by ${incident.createdByName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: status.color.withValues(alpha: 0.6)),
            ),
            child: Text(
              status.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'WHAT HAPPENED',
      children: [
        Text(
          incident.description,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        _Row(label: 'Reported reason', value: incident.reason),
        _Row(
          label: 'Date & time',
          value: dateTimeLabel(incident.incidentAt),
        ),
        _Row(label: 'District', value: incident.district),
        _Row(label: 'Barangay', value: incident.barangay),
        if (incident.truckPlate?.trim().isNotEmpty == true)
          _Row(label: 'Truck', value: incident.truckPlate!),
        if (incident.route?.trim().isNotEmpty == true)
          _Row(label: 'Route', value: incident.route!),
        _Row(label: 'Sender', value: '${incident.createdByName} · DSQC'),
        if (incident.officerUids.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No District Officer was assigned to this district when the SOS '
              'was sent. City Hall must assign one.',
              style: TextStyle(
                fontSize: 9.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _Coordination extends StatelessWidget {
  const _Coordination({
    required this.incident,
    required this.updating,
    required this.onContact,
    required this.onResolve,
  });

  final SosIncident incident;
  final bool updating;
  final VoidCallback onContact;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final resolved = incident.status == SosStatus.resolved;
    return _Card(
      title: 'ACTIONS',
      children: [
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: onContact,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.contact_phone_rounded, size: 18),
            label: const Text('Contact Barangay Staff'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Calls the ${incident.barangay} desk through EcoConnect. The first '
          'call moves this incident to Coordinating on its own.',
          style: const TextStyle(
            fontSize: 9,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        if (!resolved) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: updating ? null : onResolve,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest, width: 1.2),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.task_alt_rounded, size: 18),
              label: const Text('Resolve Incident'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ending a call never resolves the incident by itself. Resolve it '
            'once the barangay has the information, with a short note on what '
            'was done.',
            style: TextStyle(
              fontSize: 8.5,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(EcoRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolved by ${incident.resolvedByName ?? incident.statusUpdatedByName ?? 'the District Officer'}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                if (incident.resolutionNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    incident.resolutionNote!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Asks for the outcome note and confirms, so a mis-tap cannot close an
/// incident that is still being worked on.
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.incident});

  final SosIncident incident;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.creamBright,
      title: const Text(
        'Resolve incident',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.forest,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.incident.code} · ${widget.incident.barangay}',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            decoration: const InputDecoration(
              labelText: 'What was done (optional)',
              hintText: 'e.g. Barangay informed, collection moved to 3 PM',
              counterStyle: TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
          child: const Text('Resolve'),
        ),
      ],
    );
  }
}

class _MonitorNote extends StatelessWidget {
  const _MonitorNote({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'MONITORING',
      children: [
        Text(
          incident.isUnassigned
              ? 'This SOS was not delivered to a District Officer. Assign an '
                    'officer to ${incident.district} from the District Officers '
                    'desk.'
              : 'Dispatched to ${incident.officerUids.length} District '
                    'Officer${incident.officerUids.length == 1 ? '' : 's'} for '
                    '${incident.district}. The status below is what the officer '
                    'records.',
          style: const TextStyle(
            fontSize: 10,
            height: 1.5,
            color: AppColors.textDark,
          ),
        ),
        if (incident.statusUpdatedByName?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Last updated by ${incident.statusUpdatedByName} · '
            '${timeAgo(incident.statusUpdatedAt)}',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final events = <(String, DateTime?, IconData)>[
      ('SOS sent by DSQC', incident.createdAt, Icons.sos_rounded),
      (
        'Alert delivered to the officer',
        incident.notifiedAt,
        Icons.notifications_active_outlined,
      ),
      (
        'Acknowledged by the officer',
        incident.acknowledgedAt,
        Icons.check_circle_outline_rounded,
      ),
      (
        'Coordinating with the barangay',
        incident.coordinatingAt,
        Icons.phone_in_talk_rounded,
      ),
      ('Resolved', incident.resolvedAt, Icons.task_alt_rounded),
    ].where((event) => event.$2 != null).toList();

    return _Card(
      title: 'INCIDENT TIMELINE',
      children: [
        if (events.isEmpty)
          const Text(
            'The timestamps appear here as the incident moves forward.',
            style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          )
        else
          for (var i = 0; i < events.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == events.length - 1 ? 0 : 9),
              child: Row(
                children: [
                  Icon(events[i].$3, size: 14, color: AppColors.forest),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      events[i].$1,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    dateTimeLabel(events[i].$2),
                    style: const TextStyle(
                      fontSize: 8.5,
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

class _IncidentCalls extends StatelessWidget {
  const _IncidentCalls({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid ?? '';
    final cityHall = user?.role == UserRole.cityHall;
    return _Card(
      title: 'CALLS FOR THIS INCIDENT',
      children: [
        StreamBuilder<List<CallLog>>(
          stream: CallService().watchForIncident(
            incident.id,
            viewerUid: uid,
            all: cityHall,
          ),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? const <CallLog>[];
            if (!snapshot.hasData) {
              return const Text(
                'Loading calls…',
                style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
              );
            }
            if (logs.isEmpty) {
              return const Text(
                'No call has been made about this incident yet.',
                style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
              );
            }
            return Column(
              children: [
                for (final log in logs) ...[
                  Row(
                    children: [
                      Icon(
                        log.outcome == CallOutcome.completed
                            ? Icons.call_rounded
                            : Icons.call_missed_rounded,
                        size: 14,
                        color: log.outcome == CallOutcome.completed
                            ? AppColors.forest
                            : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${log.contactFor(uid)} · ${log.outcome.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        log.durationSeconds > 0
                            ? '${(log.durationSeconds / 60).floor()}:'
                                  '${(log.durationSeconds % 60).toString().padLeft(2, '0')}'
                            : timeAgo(log.startedAt),
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.inkMuted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
