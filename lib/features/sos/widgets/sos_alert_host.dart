import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sos_incident.dart';
import '../services/sos_alarm.dart';
import '../services/sos_service.dart';

/// Rings the District Officer's device when a new SOS lands while the app is
/// running. Background and closed-app delivery is the push notification's job;
/// this is the in-app alert with the full incident on screen.
///
/// The siren and the vibration come from [SosAlarm], which keeps the loop
/// running in the platform audio player and vibrator — not in a widget timer —
/// so it survives the app being backgrounded or the screen being locked. It
/// stops the moment the alert is opened or the incident stops being a new
/// alert, and it can never run twice for the same incident.
class SosAlertHost extends StatefulWidget {
  const SosAlertHost({super.key, required this.child});

  final Widget child;

  @override
  State<SosAlertHost> createState() => _SosAlertHostState();
}

class _SosAlertHostState extends State<SosAlertHost> {
  StreamSubscription<List<SosIncident>>? _sub;
  final Set<String> _seen = {};
  final List<SosIncident> _queue = [];
  bool _primed = false;
  bool _showing = false;
  String? _streamKey;

  /// The incident the siren is currently ringing for, if any.
  String? _alarmId;

  /// An incident this young is still live when the app opens, so an officer
  /// whose app was closed is still alerted instead of silently missing it.
  static const Duration _freshWindow = Duration(minutes: 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final key = user == null ? null : '${user.uid}:${user.role.name}';
    if (key == _streamKey) return;
    _streamKey = key;
    _sub?.cancel();
    _sub = null;
    _seen.clear();
    _queue.clear();
    _primed = false;
    _alarmId = null;
    unawaited(SosAlarm.instance.stop());

    if (user == null || user.role != UserRole.districtOfficer) return;
    _sub = SosService()
        .watchForOfficer(uid: user.uid, district: user.district)
        .listen(_onIncidents, onError: (_) {});
  }

  void _onIncidents(List<SosIncident> incidents) {
    // Somebody else acknowledged or resolved the alert on screen. The dialog
    // may stay until the officer dismisses it, but the siren must stop.
    final alarmId = _alarmId;
    if (alarmId != null) {
      final current = incidents.where((incident) => incident.id == alarmId);
      final stillNew =
          current.isNotEmpty && current.first.status == SosStatus.newAlert;
      if (!stillNew) {
        _alarmId = null;
        unawaited(SosAlarm.instance.stop());
      }
    }

    if (!_primed) {
      _primed = true;
      final now = DateTime.now();
      final live = incidents.where((incident) {
        if (incident.status != SosStatus.newAlert) return false;
        final created = incident.createdAt;
        return created != null && now.difference(created) < _freshWindow;
      }).toList();
      _seen.addAll(incidents.map((incident) => incident.id));
      if (live.isEmpty || !mounted) return;
      _queue.addAll(live);
      _showNext();
      return;
    }

    final fresh = incidents
        .where(
          (incident) =>
              incident.status == SosStatus.newAlert &&
              !_seen.contains(incident.id),
        )
        .toList();
    _seen.addAll(incidents.map((incident) => incident.id));
    if (fresh.isEmpty || !mounted) return;
    _queue.addAll(fresh);
    _showNext();
  }

  Future<void> _showNext() async {
    if (_showing || _queue.isEmpty || !mounted) return;
    final incident = _queue.removeAt(0);
    await _show(incident);
    if (mounted) _showNext();
  }

  Future<void> _show(SosIncident incident) async {
    _showing = true;
    _alarmId = incident.id;
    unawaited(SosAlarm.instance.start());
    final user = context.read<AuthProvider>().currentUser;

    final action = await showDialog<_SosAlertAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SosAlert(incident: incident),
    );
    // Closing the alert always silences the siren. "Later" leaves the record
    // as a new alert; it is not an acknowledgement and it is not resolved.
    await SosAlarm.instance.stop();
    _alarmId = null;
    _showing = false;
    if (!mounted) return;

    // Opening the alert is the acknowledgement, so there is no second button
    // to press.
    if (action == _SosAlertAction.open && user != null) {
      try {
        await SosService().markAcknowledged(
          incident.id,
          uid: user.uid,
          name: user.displayName ?? 'District Officer',
        );
      } catch (_) {
        // The incident still opens; the detail screen retries this on load.
      }
      if (!mounted) return;
      context.push('/sos/${incident.id}');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(SosAlarm.instance.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _SosAlertAction { open, later }

class _SosAlert extends StatelessWidget {
  const _SosAlert({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.error, width: 1.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    size: 21,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'SOS ALERT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.error,
                    ),
                  ),
                ),
                Text(
                  incident.code,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              incident.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            _Line(icon: Icons.info_outline_rounded, text: incident.reason),
            _Line(
              icon: Icons.place_outlined,
              text: '${incident.barangay}, ${incident.district}',
            ),
            _Line(
              icon: Icons.schedule_rounded,
              text: dateTimeLabel(incident.incidentAt),
            ),
            const SizedBox(height: 4),
            const Text(
              'The full details are already in the incident. Contact the '
              'barangay directly from the incident screen.',
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_SosAlertAction.open),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Open incident'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_SosAlertAction.later),
              child: const Text(
                'Later',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
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
