import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../models/delay_report.dart';
import '../services/delay_service.dart';
import '../widgets/district_officer_alarm.dart';
import '../../../core/widgets/desk_ui.dart';

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
    'Late crew start',
    'Waiting at collection point',
    'Weather',
    'Other',
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
    return EcoPageScaffold(
      eyebrow: 'ISWIM · DELAY DESK',
      title: 'File a delay report',
      subtitle:
          'Name the plate and the reason. The DSQC sees it immediately, then '
          'passes it to the district officer and the barangay.',
      onBack: () => ecoBack(context, '/iswim'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
          children: [
            _FormSection(
              title: 'THE ROUND',
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
                  validator: (value) => value == null ? 'Select a truck' : null,
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
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _reason = value ?? _reason),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormSection(
              title: 'HOW LATE',
              children: [
                TextFormField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes late',
                    suffixText: 'min',
                    isDense: true,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter the minutes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                    hintText: 'Anything the desk should know on the ground',
                    isDense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: const Text('Send to DSQC'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Iswim → DSQC → District Officer (alarm on the DSQC device) → '
              'Barangay copy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
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

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

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

/// The delay list. DSQC can push to the district officer, the barangay can
/// close its copy.
class DelayListScreen extends StatefulWidget {
  const DelayListScreen({
    super.key,
    required this.canForward,
    this.canAnnounce = false,
  });

  /// Barangay staff announce delays City Hall sent down to residents.
  final bool canAnnounce;

  /// True on the DSQC device: shows the "push to district officer" action.
  final bool canForward;

  @override
  State<DelayListScreen> createState() => _DelayListScreenState();
}

class _DelayListScreenState extends State<DelayListScreen> {
  final _search = TextEditingController();
  String _query = '';
  DelayStage? _stage;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DelayReport> _filter(List<DelayReport> reports) {
    final q = _query.trim().toLowerCase();
    return reports.where((r) {
      if (_stage != null && r.stage != _stage) return false;
      if (q.isEmpty) return true;
      return r.code.toLowerCase().contains(q) ||
          r.plateNumber.toLowerCase().contains(q) ||
          r.reason.toLowerCase().contains(q) ||
          r.driverName.toLowerCase().contains(q);
    }).toList();
  }

  int _count(List<DelayReport> reports, DelayStage stage) =>
      reports.where((report) => report.stage == stage).length;

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _stage = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canForward = widget.canForward;
    final canAnnounce = widget.canAnnounce;
    final eyebrow = canForward
        ? 'CITY HALL · DELAY REPORTS'
        : canAnnounce
        ? 'BARANGAY · DELAY REPORTS'
        : 'DELAY DESK';

    return EcoPageScaffold(
      eyebrow: eyebrow,
      title: 'Delay reports',
      subtitle: canForward
          ? 'Late collections filed by Iswim. Push one to the district officer '
                'or send the barangay its copy.'
          : 'Late collections filed by Iswim, newest first.',
      onBack: () => ecoBack(
        context,
        canForward
            ? '/cityhall'
            : canAnnounce
            ? '/admin-dashboard'
            : '/iswim',
      ),
      body: StreamBuilder<List<DelayReport>>(
        stream: DelayService().watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const EcoLoadingView(label: 'Loading delay reports');
          }

          final reports = snapshot.data ?? const <DelayReport>[];
          final items = _filter(reports);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);
          final filtered = _query.trim().isNotEmpty || _stage != null;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.timer_outlined,
                label: 'At DSQC',
                value: '${_count(reports, DelayStage.dsqc)}',
                accent: AppColors.warning,
                highlight: _count(reports, DelayStage.dsqc) > 0,
              ),
              DeskMetric(
                icon: Icons.local_police_outlined,
                label: 'With district',
                value: '${_count(reports, DelayStage.districtOfficer)}',
              ),
              DeskMetric(
                icon: Icons.campaign_outlined,
                label: 'Announced',
                value:
                    '${reports.where((r) => r.announcementId != null).length}',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search ticket, plate or reason',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<DelayStage?>(
              value: _stage,
              onChanged: (value) => setState(() {
                _stage = value;
                _page = 0;
              }),
              segments: [
                DeskSegment(value: null, label: 'All', count: reports.length),
                DeskSegment(
                  value: DelayStage.dsqc,
                  label: 'DSQC',
                  count: _count(reports, DelayStage.dsqc),
                ),
                DeskSegment(
                  value: DelayStage.districtOfficer,
                  label: 'District',
                  count: _count(reports, DelayStage.districtOfficer),
                ),
                DeskSegment(
                  value: DelayStage.barangay,
                  label: 'Barangay',
                  count: _count(reports, DelayStage.barangay),
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: filtered
                  ? 'Showing ${items.length} of ${reports.length} reports'
                  : '${reports.length} '
                        '${reports.length == 1 ? 'report' : 'reports'}',
              onClear: filtered ? _clear : null,
            ),
            empty: reports.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.timer_outlined,
                    title: 'No delay reports yet',
                    message:
                        'When a collection runs late, Iswim files it here '
                        'and the DSQC decides who needs to know.',
                    steps: [
                      'Iswim files the late round',
                      'DSQC pushes it to the district officer',
                      'The barangay gets its copy',
                    ],
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No report matches',
                    message:
                        'Try another plate or reason, or clear the stage '
                        'filter.',
                    actionLabel: 'Clear filters',
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: _clear,
                  ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _DelayCard(
              report: visible[i],
              canForward: canForward,
              canAnnounce: canAnnounce,
            ),
            pagination: items.isEmpty
                ? null
                : EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: items.length,
                    onPageChanged: (next) => setState(() => _page = next),
                    onPageSizeChanged: (size) => setState(() {
                      _pageSize = size;
                      _page = 0;
                    }),
                  ),
          );
        },
      ),
    );
  }
}

class _DelayCard extends StatelessWidget {
  const _DelayCard({
    required this.report,
    required this.canForward,
    this.canAnnounce = false,
  });

  final DelayReport report;
  final bool canForward;
  final bool canAnnounce;

  static Color _stageColor(DelayStage stage) => switch (stage) {
    DelayStage.dsqc => AppColors.warning,
    DelayStage.districtOfficer => const Color(0xFF1565C0),
    DelayStage.barangay => AppColors.primary,
    DelayStage.closed => AppColors.inkMuted,
  };

  static int _stageIndex(DelayStage stage) => switch (stage) {
    DelayStage.dsqc => 0,
    DelayStage.districtOfficer => 1,
    DelayStage.barangay => 2,
    DelayStage.closed => 3,
  };

  Future<void> _announce(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Announce this delay?'),
        content: Text(
          'Every resident gets a notification and sees it under '
          'Announcements: truck ${report.plateNumber} is about '
          '${report.minutesLate} min late (${report.reason}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Announce'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DelayService().announceToResidents(
        report,
        authorId: user.uid,
        authorName: user.displayName ?? 'Barangay Batasan Hills',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Delay announced to residents')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not announce the delay: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = report.stage;
    final stageColor = _stageColor(stage);

    return DeskRailCard(
      railColor: stageColor,
      padding: const EdgeInsets.fromLTRB(17, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(EcoRadius.sm - 2),
                ),
                child: Text(
                  report.code,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(label: stage.label, color: stageColor, compact: true),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.plateNumber,
                      style: EcoType.identifier(
                        context,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${report.minutesLate}',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB26A00),
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'MIN LATE',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFFB26A00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                timeAgo(report.createdAt),
                style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
              ),
            ],
          ),
          if (report.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(EcoRadius.sm),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                report.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 11),
          _StageTrack(current: _stageIndex(stage)),
          if (canForward && stage == DelayStage.dsqc) ...[
            const SizedBox(height: 11),
            SizedBox(
              height: 38,
              child: FilledButton.icon(
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
                icon: const Icon(Icons.campaign_rounded, size: 15),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                label: const Text('Forward to District Officer'),
              ),
            ),
          ],
          if (canForward && stage == DelayStage.districtOfficer) ...[
            const SizedBox(height: 11),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => DelayService().sendToBarangay(report),
                icon: const Icon(Icons.send_outlined, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.sage),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                label: const Text('Send a copy to the Barangay'),
              ),
            ),
          ],
          if (canAnnounce &&
              stage == DelayStage.barangay &&
              report.announcementId == null) ...[
            const SizedBox(height: 11),
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () => _announce(context),
                icon: const Icon(Icons.campaign_outlined, size: 15),
                label: const Text('Announce to residents'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (report.announcementId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Announced to residents${report.announcedAt == null ? '' : ' · ${timeAgo(report.announcedAt)}'}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Three dots joined by a rule: DSQC → District → Barangay.
class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['DSQC', 'District', 'Barangay'];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: current > i - 1
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.sage.withValues(alpha: 0.6),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 13,
                width: 13,
                decoration: BoxDecoration(
                  color: current >= i ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current >= i ? AppColors.primary : AppColors.sage,
                    width: 1.4,
                  ),
                ),
                child: current > i
                    ? const Icon(
                        Icons.check_rounded,
                        size: 8,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: current >= i
                      ? AppColors.forest
                      : AppColors.inkMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
