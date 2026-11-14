import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/delay_report.dart';

/// The district officer has no account, so this is how they are "told":
/// a loud alert on the DSQC device — sound, vibration, and the full report on
/// screen — instead of a login they would have to remember.
Future<void> showDistrictOfficerAlarm(
  BuildContext context,
  DelayReport report,
  Future<void> Function() onSendToBarangay,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DistrictOfficerAlarm(
      report: report,
      onSendToBarangay: onSendToBarangay,
    ),
  );
}

class _DistrictOfficerAlarm extends StatefulWidget {
  const _DistrictOfficerAlarm({
    required this.report,
    required this.onSendToBarangay,
  });

  final DelayReport report;
  final Future<void> Function() onSendToBarangay;

  @override
  State<_DistrictOfficerAlarm> createState() => _DistrictOfficerAlarmState();
}

class _DistrictOfficerAlarmState extends State<_DistrictOfficerAlarm> {
  Timer? _buzz;
  int _pulses = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ring();
  }

  /// Three heavy pulses: long enough to notice, short enough to stop.
  void _ring() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      _pulses++;
      if (_pulses >= 4) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _buzz?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.error, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'District Officer alert',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              report.code,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            _line('Truck', report.plateNumber),
            _line('Driver', report.driverName),
            _line('Reason', report.reason),
            _line('Late', '${report.minutesLate} minutes'),
            if (report.ticketCode != null)
              _line('Ticket', report.ticketCode!),
            if (report.notes.trim().isNotEmpty) _line('Notes', report.notes),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onSendToBarangay();
                          if (context.mounted) Navigator.of(context).pop();
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Ipadala ang copy sa Barangay'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Isara muna',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
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
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
