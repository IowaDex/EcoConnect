import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/constants/service_districts.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/sos_service.dart';

/// DSQC's SOS form. The alert is only sent after the officer-facing details are
/// complete and confirmed, never from a single tap on an empty button.
class SosFormScreen extends StatefulWidget {
  const SosFormScreen({super.key});

  @override
  State<SosFormScreen> createState() => _SosFormScreenState();
}

class _SosFormScreenState extends State<SosFormScreen> {
  static const _reasons = [
    'Garbage truck delay',
    'Garbage truck breakdown',
    'Missed collection',
    'Late crew start',
    'Waiting at collection point',
    'Traffic / road closure',
    'Weather',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();

  String _reason = _reasons.first;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  bool _sending = false;

  /// One id per form session. A double tap or a retry reuses it, so the same
  /// SOS cannot be written twice.
  late final String _submissionId;

  @override
  void initState() {
    super.initState();
    final random = Random.secure();
    _submissionId =
        'sos_${DateTime.now().millisecondsSinceEpoch}_'
        '${List.generate(4, (_) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  DateTime get _incidentAt => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _time.hour,
    _time.minute,
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Incident date',
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Incident time',
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _reviewAndSend() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;

    final description = _description.text.trim();
    final reason = _reason;
    final when = _incidentAt;
    // The barangay and its district are fixed: EcoConnect serves one area, so
    // asking for them again only invited a mismatch with the officer's
    // assignment.
    const district = ServiceDistricts.defaultDistrict;
    const barangay = ServiceArea.barangay;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.creamBright,
        title: const Row(
          children: [
            Icon(Icons.sos_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Send this SOS?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The District Officer covering this district will be alerted '
                'with sound, vibration and a push notification.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              _ReviewLine(label: 'What happened', value: description),
              _ReviewLine(label: 'Reason', value: reason),
              _ReviewLine(
                label: 'Date & time',
                value: '${dateLabel(when)} · ${timeLabel(when)}',
              ),
              const _ReviewLine(label: 'District', value: district),
              const _ReviewLine(label: 'Barangay', value: barangay),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Review again'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.sos_rounded, size: 16),
            label: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final dispatch = await SosService().send(
        submissionId: _submissionId,
        description: description,
        reason: reason,
        incidentAt: when,
        district: district,
        barangay: barangay,
        createdBy: user.uid,
        createdByName: user.displayName ?? 'City Hall · DSQC',
      );
      if (!mounted) return;
      await _showResult(dispatch);
      if (!mounted) return;
      context.pushReplacement('/sos/${dispatch.incident.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not send the SOS: $error'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showResult(SosDispatch dispatch) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.creamBright,
        title: Text(
          dispatch.reachedAnyone ? 'SOS sent' : 'SOS saved — no officer',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: dispatch.reachedAnyone ? AppColors.forest : AppColors.error,
          ),
        ),
        content: Text(
          dispatch.reachedAnyone
              ? '${dispatch.incident.code} was dispatched to '
                    '${dispatch.officerCount} District Officer'
                    '${dispatch.officerCount == 1 ? '' : 's'} for '
                    '${dispatch.incident.district}.'
              : '${dispatch.incident.code} was saved, but no active District '
                    'Officer covers ${dispatch.incident.district}. Assign one '
                    'from the District Officers desk, then contact the '
                    'barangay directly.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'CITY HALL · DSQC SOS',
      title: 'File an SOS incident',
      subtitle:
          'Enter what ISWIM reported. The officer receives the complete '
          'incident, so nobody has to call DSQC to ask what happened.',
      icon: Icons.sos_rounded,
      onBack: () => ecoBack(context, '/cityhall'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
          children: [
            const _Section(
              title: 'WHAT HAPPENED',
              children: [
                _Help(
                  text:
                      'Describe the delay or problem in the words the officer '
                      'and the barangay will need. Include what ISWIM reported.',
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Incident description',
                hintText:
                    'Example: Truck 3 stopped at Commonwealth Ave. Hydraulic '
                    'line broke; collection in Batasan Hills will run 2 hours late.',
                alignLabelWithHint: true,
                isDense: true,
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Describe the incident';
                if (text.length < 10) {
                  return 'Add a little more detail (at least 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Reported reason',
                isDense: true,
              ),
              items: [
                for (final reason in _reasons)
                  DropdownMenuItem(
                    value: reason,
                    child: Text(reason, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Choose a reason' : null,
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'WHEN',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: dateLabel(_date),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        value: timeLabel(_incidentAt),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _Help(
                  text:
                      'Use Philippine time. The date and time are shown to the '
                      'officer exactly as entered here.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _sending ? null : _reviewAndSend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sos_rounded, size: 19),
                label: Text(_sending ? 'Sending SOS…' : 'Review and send SOS'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ISWIM reports → DSQC enters the details → DSQC confirms → '
              'the District Officer is alerted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

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
              fontSize: 9,
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

class _Help extends StatelessWidget {
  const _Help({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9.5,
        height: 1.5,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.forest),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                size: 14,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
