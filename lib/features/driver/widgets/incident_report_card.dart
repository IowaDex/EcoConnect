import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../incident/models/driver_incident.dart';
import '../../incident/services/driver_incident_service.dart';
import '../../location/providers/location_provider.dart';

/// "Something happened on the road."
///
/// A crew member reports an accident, a breakdown or a blocked street to the
/// Iswim desk. Iswim decides whether the round is delayed and files the formal
/// delay report — the crew never guesses at a delay stage.
class IncidentReportCard extends StatelessWidget {
  const IncidentReportCard({
    super.key,
    required this.plateNumber,
    this.zone = '',
    this.ticketId,
  });

  final String plateNumber;
  final String zone;
  final String? ticketId;

  Future<void> _open(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final location = context.read<LocationProvider>();

    final draft = await showModalBottomSheet<_IncidentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamBright,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (_) => _IncidentSheet(plateNumber: plateNumber),
    );
    if (draft == null || !context.mounted) return;

    try {
      await DriverIncidentService().submit(
        driverId: user.uid,
        driverName: user.displayName ?? 'Crew',
        plateNumber: plateNumber,
        zone: zone,
        ticketId: ticketId,
        kind: draft.kind,
        description: draft.description,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Report sent to Iswim. They decide whether the round is delayed.',
            ),
            backgroundColor: AppColors.forest,
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not send the report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.report_problem_outlined,
                size: 17,
                color: AppColors.warning,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Something happened on the road?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Report an accident or breakdown to Iswim so the round '
                      'is not marked late without a reason.',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.45,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _open(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Report',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (uid != null) _LatestReport(driverId: uid),
        ],
      ),
    );
  }
}

/// The crew's newest report and whether Iswim has seen it, so a driver who
/// filed one at 6 a.m. does not have to ask the desk whether it arrived.
class _LatestReport extends StatelessWidget {
  const _LatestReport({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverIncident>>(
      stream: DriverIncidentService().watchMine(driverId),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <DriverIncident>[];
        if (reports.isEmpty) return const SizedBox.shrink();
        final latest = reports.first;
        final colour = switch (latest.status) {
          DriverIncidentStatus.open => AppColors.warning,
          DriverIncidentStatus.acknowledged => AppColors.forest,
          DriverIncidentStatus.closed => AppColors.inkMuted,
        };
        return Padding(
          padding: const EdgeInsets.only(left: 26, top: 8),
          child: Row(
            children: [
              Icon(latest.kind.icon, size: 12, color: colour),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Your last report · ${latest.kind.label} · '
                  '${latest.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IncidentDraft {
  const _IncidentDraft({required this.kind, required this.description});

  final DriverIncidentKind kind;
  final String description;
}

class _IncidentSheet extends StatefulWidget {
  const _IncidentSheet({required this.plateNumber});

  final String plateNumber;

  @override
  State<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<_IncidentSheet> {
  final _description = TextEditingController();
  DriverIncidentKind _kind = DriverIncidentKind.accident;
  bool _showError = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _description.text.trim();
    if (text.length < 5) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(_IncidentDraft(kind: _kind, description: text));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT AN INCIDENT',
            style: EcoType.eyebrow(context, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Truck ${widget.plateNumber}',
            style: EcoType.panelTitle(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 4),
          Text(
            'Iswim reads this on the delay desk. It does not file the delay '
            'for you — it tells them why the round may run late.',
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final kind in DriverIncidentKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                  labelStyle: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _kind == kind ? Colors.white : AppColors.forest,
                  ),
                  selectedColor: AppColors.forest,
                  backgroundColor: AppColors.mint,
                  side: BorderSide(
                    color: _kind == kind ? AppColors.forest : AppColors.sage,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What happened?',
              hintText: 'e.g. Flat tyre on Filinvest 1, waiting for a spare.',
              errorText: _showError
                  ? 'Describe what happened so Iswim can act on it.'
                  : null,
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text('Send to Iswim'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
