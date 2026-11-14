import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../models/delay_report.dart';
import '../services/delay_service.dart';
import '../widgets/district_officer_alarm.dart';

/// Iswim files the delay report. Truck and driver come from the fleet roster,
/// so the report always names a real plate.
class FileDelayScreen extends StatefulWidget {
  const FileDelayScreen({super.key});

  @override
  State<FileDelayScreen> createState() => _FileDelayScreenState();
}

class _FileDelayScreenState extends State<FileDelayScreen> {
  static const _reasons = [
    'Traffic / road closure',
    'Truck breakdown',
    'Late start ng crew',
    'Waiting sa collection point',
    'Weather',
    'Iba pa',
  ];

  final _formKey = GlobalKey<FormState>();
  final _minutes = TextEditingController(text: '30');
  final _notes = TextEditingController();

  GarbageTruck? _truck;
  String _reason = _reasons.first;
  bool _busy = false;
  List<GarbageTruck> _trucks = const [];
  StreamSubscription<List<GarbageTruck>>? _fleetSub;

  @override
  void initState() {
    super.initState();
    _fleetSub = FleetService().watchTrucks().listen((trucks) {
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        final current = _truck;
        if (current != null) {
          _truck = trucks.cast<GarbageTruck?>().firstWhere(
                (t) => t?.id == current.id,
                orElse: () => null,
              );
        }
      });
    });
  }

  @override
  void dispose() {
    _fleetSub?.cancel();
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final truck = _truck;
    final user = context.read<AuthProvider>().currentUser;
    if (truck == null || user == null) return;

    setState(() => _busy = true);
    try {
      await DelayService().file(
        plateNumber: truck.plateNumber,
        driverName: truck.driverName,
        reason: _reason,
        minutesLate: int.tryParse(_minutes.text.trim()) ?? 0,
        notes: _notes.text.trim(),
        filedBy: user.uid,
        filedByName: user.displayName ?? 'Iswim',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Delay report sent to DSQC'),
            backgroundColor: AppColors.forest,
          ),
        );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not file the report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Delay report',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            DropdownButtonFormField<GarbageTruck>(
              initialValue: _truck,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Truck',
                isDense: true,
              ),
              items: [
                for (final truck in _trucks)
                  DropdownMenuItem(
                    value: truck,
                    child: Text(
                      '${truck.plateNumber} · ${truck.driverName}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _truck = value),
              validator: (value) => value == null ? 'Pumili ng truck' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Reason',
                isDense: true,
              ),
              items: [
                for (final reason in _reasons)
                  DropdownMenuItem(
                    value: reason,
                    child: Text(reason, style: const TextStyle(fontSize: 11)),
                  ),
              ],
              onChanged: (value) => setState(() => _reason = value ?? _reason),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ilang minuto late',
                isDense: true,
              ),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Ilagay ang minutes';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalye (optional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ipadala sa DSQC'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Iswim → DSQC → District Officer (alarm sa DSQC device) → '
              'Barangay copy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The delay list. DSQC can push to the district officer, the barangay can
/// close its copy.
class DelayListScreen extends StatelessWidget {
  const DelayListScreen({super.key, required this.canForward});

  /// True on the DSQC device: shows the "push to district officer" action.
  final bool canForward;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/cityhall');
            }
          },
        ),
        title: const Text(
          'Delay reports',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<DelayReport>>(
        stream: DelayService().watchAll(),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <DelayReport>[];
          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'Wala pang delay report.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              for (final report in reports) ...[
                _DelayCard(report: report, canForward: canForward),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DelayCard extends StatelessWidget {
  const _DelayCard({required this.report, required this.canForward});

  final DelayReport report;
  final bool canForward;

  @override
  Widget build(BuildContext context) {
    final stage = report.stage;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                report.code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                stage.label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: stage == DelayStage.dsqc
                      ? AppColors.warning
                      : AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${report.plateNumber} · ${report.driverName}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${report.reason} · ${report.minutesLate} min late',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          if (canForward && stage == DelayStage.dsqc) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: FilledButton(
                onPressed: () async {
                  final service = DelayService();
                  await service.forwardToDistrictOfficer(report);
                  if (!context.mounted) return;
                  // The officer has no account: the alert has to happen here.
                  await showDistrictOfficerAlarm(
                    context,
                    report,
                    () => service.sendToBarangay(report),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('I-forward sa District Officer'),
              ),
            ),
          ],
          if (canForward && stage == DelayStage.districtOfficer) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: () => DelayService().sendToBarangay(report),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.sage),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Ipadala ang copy sa Barangay'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
