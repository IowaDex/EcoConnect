import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_config.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../../tickets/models/trip_ticket.dart';
import '../data/manual_areas.dart';
import '../models/manual_assignment.dart';
import '../services/assignment_manual_service.dart';
import '../services/manual_draft_store.dart';
import '../services/manual_pdf.dart';
import '../widgets/manual_route_map.dart';

/// A driver account Iswim can put on a manual.
class _DriverOption {
  const _DriverOption({required this.uid, required this.name, this.truckId});

  final String uid;
  final String name;
  final String? truckId;

  String get key => uid.isNotEmpty ? 'uid:$uid' : 'name:$name';
}

/// One row Iswim has built but not submitted yet.
class _DraftAssignment {
  _DraftAssignment({
    required this.driverId,
    required this.driverName,
    required this.truck,
    required this.routes,
    required this.days,
    required this.startTime,
    required this.recurrence,
  });

  final String driverId;
  final String driverName;
  final GarbageTruck truck;
  final List<ManualArea> routes;
  final Set<int> days;
  final TimeOfDay startTime;
  final ManualRecurrence recurrence;

  int get maxRoutes => maxRoutesForWheelers(truck.wheelers);

  String get startLabel =>
      '${startTime.hour.toString().padLeft(2, '0')}:'
      '${startTime.minute.toString().padLeft(2, '0')}';

  String get daysLabel => ([...days]..sort()).map(manualDayLabel).join(' · ');

  /// The last day this row's schedule covers, counted from today.
  DateTime get validUntil =>
      manualValidUntil(recurrence: recurrence, from: DateTime.now());

  String get validityLabel => 'Valid until ${dateLabel(validUntil)}';

  List<String> get routeNames => [for (final area in routes) area.name];

  ManualAssignment toManualAssignment() => ManualAssignment(
    driverId: driverId,
    driverName: driverName,
    truckId: truck.id,
    plateNumber: truck.plateNumber,
    wheelers: truck.wheelers,
    routes: routeNames,
    routePoints: [
      for (final area in routes)
        ManualRoutePoint(
          name: area.name,
          latitude: area.center.latitude,
          longitude: area.center.longitude,
        ),
    ],
    days: [...days]..sort(),
    startTime: startLabel,
    recurrence: recurrence,
  );
}

class _SheetResult {
  const _SheetResult({required this.draft, required this.addAnother});

  final _DraftAssignment draft;
  final bool addAnother;
}

const _letterColors = <Color>[
  Color(0xFF2E7D32),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF8E24AA),
  Color(0xFFF9A825),
  Color(0xFF6D4C41),
];

Color _letterColor(int index) => _letterColors[index % _letterColors.length];

String _letter(int index) =>
    String.fromCharCode('A'.codeUnitAt(0) + (index % 26));

/// `HH:mm` as `8:00 AM`, for the rows of the week grid.
String _clockLabel(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display:${minute.toString().padLeft(2, '0')} '
      '${hour < 12 ? 'AM' : 'PM'}';
}

/// Iswim builds the collection manual City Hall asked for.
///
/// The manual is a bulk assignment: the officer adds one row per driver, each
/// with the truck that comes with the account, the areas the truck covers, the
/// days, the start time and how long the schedule repeats. The review step
/// sends the whole roster to City Hall, which signs one trip ticket per row.
class CreateAssignmentManualScreen extends StatefulWidget {
  const CreateAssignmentManualScreen({
    super.key,
    this.requestId,
    this.requestTitle = '',
  });

  final String? requestId;
  final String requestTitle;

  @override
  State<CreateAssignmentManualScreen> createState() =>
      _CreateAssignmentManualScreenState();
}

class _CreateAssignmentManualScreenState
    extends State<CreateAssignmentManualScreen> {
  final _title = TextEditingController();
  final List<_DraftAssignment> _assignments = [];

  List<_DriverOption> _accounts = const [];
  List<GarbageTruck> _trucks = const [];
  StreamSubscription<List<GarbageTruck>>? _truckSub;
  bool _busy = false;
  bool _loadingDrivers = true;

  /// 0 = drivers & routes, 1 = review.
  int _step = 0;

  /// The draft key: one unfinished manual per City Hall request.
  String get _draftScope => widget.requestId ?? 'new';

  /// What the title started as, so leaving an untouched page is silent.
  late final String _initialTitle = widget.requestTitle.trim().isEmpty
      ? 'Collection manual'
      : widget.requestTitle.trim();

  @override
  void initState() {
    super.initState();
    _title.text = _initialTitle;
    _truckSub = FleetService().watchTrucks().listen(
      (trucks) {
        if (mounted) setState(() => _trucks = trucks);
      },
      // Offline or rules blocked: the add sheet still opens and explains that
      // the fleet is empty instead of throwing into the zone.
      onError: (_) {},
    );
    _loadDrivers();
    _restoreDraft();
  }

  @override
  void dispose() {
    _truckSub?.cancel();
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .limit(100)
          .get();
      if (!mounted) return;
      setState(() {
        _accounts = snap.docs
            .map((doc) {
              final data = doc.data();
              final name = (data['name'] as String?)?.trim();
              return _DriverOption(
                uid: doc.id,
                name: name == null || name.isEmpty
                    ? (data['email'] as String? ?? 'Driver')
                    : name,
                truckId: data['assignedTruckId'] as String?,
              );
            })
            .toList(growable: false);
        _loadingDrivers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  /// Account drivers first, then the roster names on trucks that have no
  /// login yet, so every plate in the fleet can be scheduled.
  List<_DriverOption> _options() {
    final options = <_DriverOption>[..._accounts];
    for (final truck in _trucks) {
      final name = truck.driverName.trim();
      if (name.isEmpty || name.toLowerCase() == 'unassigned') continue;
      final covered = options.any(
        (option) =>
            option.truckId == truck.id ||
            option.name.toLowerCase() == name.toLowerCase(),
      );
      if (!covered) {
        options.add(_DriverOption(uid: '', name: name, truckId: truck.id));
      }
    }
    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  /// Whether leaving now would throw work away.
  bool get _hasProgress =>
      _assignments.isNotEmpty || _title.text.trim() != _initialTitle;

  /// Rebuilds a manual the officer left half finished.
  Future<void> _restoreDraft() async {
    final draft = await ManualDraftStore().load(_draftScope);
    if (draft == null || !mounted) return;
    final rows = <_DraftAssignment>[];
    for (final row in draft.assignments) {
      final areas = manualAreasFor(row.routes);
      if (areas.isEmpty) continue;
      rows.add(
        _DraftAssignment(
          driverId: row.driverId,
          driverName: row.driverName,
          truck: _truckFor(row),
          routes: areas,
          days: row.days.toSet(),
          startTime: _timeOfDay(row.startTime),
          recurrence: row.recurrence,
        ),
      );
    }
    setState(() {
      if (draft.title.trim().isNotEmpty) _title.text = draft.title;
      _assignments
        ..clear()
        ..addAll(rows);
    });
    AppFeedback.success(context, 'Draft restored — pick up where you left off');
  }

  /// The live plate, or the one the draft remembered when it is no longer in
  /// the fleet list.
  GarbageTruck _truckFor(ManualAssignment row) {
    for (final truck in _trucks) {
      if (truck.id == row.truckId) return truck;
    }
    return GarbageTruck(
      id: row.truckId,
      plateNumber: row.plateNumber,
      wheelers: row.wheelers,
      bodyType: 'Compactor',
      barangay: 'Barangay Batasan Hills',
      zone: '',
      centerLatitude: BatasanHills.center.latitude,
      centerLongitude: BatasanHills.center.longitude,
      driverName: row.driverName,
    );
  }

  static TimeOfDay _timeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  Future<void> _saveDraft() async {
    await ManualDraftStore().save(
      _draftScope,
      ManualDraft(
        title: _title.text.trim(),
        assignments: [
          for (final assignment in _assignments) assignment.toManualAssignment(),
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    if (_hasProgress) {
      final choice = await _askAboutDraft();
      if (choice == null || !mounted) return;
      if (choice) {
        await _saveDraft();
        if (!mounted) return;
        AppFeedback.success(context, 'Draft saved');
      } else {
        await ManualDraftStore().clear(_draftScope);
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/iswim');
    }
  }

  /// True = save the draft, false = discard it, null = stay on the page.
  Future<bool?> _askAboutDraft() {
    final count = _assignments.length;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this manual as a draft?'),
        content: Text(
          count == 0
              ? 'You have not added a driver yet. Leave anyway?'
              : 'You have $count ${count == 1 ? 'assignment' : 'assignments'} '
                    'that City Hall has not seen. Save them so you can pick up '
                    'where you left off.',
          style: const TextStyle(fontSize: 12, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor({int? index}) async {
    final options = _options();
    if (options.isEmpty) {
      AppFeedback.error(
        context,
        'No drivers yet. Pair a driver account, or save a truck with a named '
        'driver, then try again.',
      );
      return;
    }
    if (_trucks.isEmpty) {
      AppFeedback.error(
        context,
        'The fleet is empty. Add a truck before assigning a driver.',
      );
      return;
    }

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentSheet(
        accounts: options,
        trucks: _trucks,
        existing: index == null ? null : _assignments[index],
        others: [
          for (var i = 0; i < _assignments.length; i++)
            if (i != index) _assignments[i],
        ],
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (index == null) {
        _assignments.add(result.draft);
      } else {
        _assignments[index] = result.draft;
      }
    });

    if (result.addAnother) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor();
      });
    }
  }

  void _remove(int index) => setState(() => _assignments.removeAt(index));

  Future<void> _exportPdf() async {
    final first = _assignments.first;
    final saved = await exportAssignmentManualPdf(
      title: _title.text,
      driverName: first.driverName,
      plateNumber: first.truck.plateNumber,
      wheelers: first.truck.wheelers,
      routes: first.routeNames,
      days: [...first.days]..sort(),
      startTime: first.startLabel,
      recurrence: first.recurrence,
      status: 'Waiting for City Hall approval',
      requestTitle: widget.requestTitle,
      assignments: [
        for (final assignment in _assignments) assignment.toManualAssignment(),
      ],
    );
    if (!mounted) return;
    if (saved) {
      AppFeedback.success(context, 'Manual PDF generated');
    } else {
      AppFeedback.error(
        context,
        'PDF download is only available in the browser build.',
      );
    }
  }

  Future<void> _submit() async {
    if (_assignments.isEmpty) {
      AppFeedback.error(context, 'Add at least one driver to this manual.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      AppFeedback.error(context, 'Give this manual a title.');
      return;
    }

    final confirmed = await _confirm();
    if (!confirmed || !mounted) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final manual = await AssignmentManualService().submitBatch(
        title: _title.text,
        assignments: [
          for (final assignment in _assignments)
            assignment.toManualAssignment(),
        ],
        byId: user.uid,
        byName: user.displayName ?? 'Iswim',
        requestId: widget.requestId,
      );
      await ManualDraftStore().clear(_draftScope);
      if (!mounted) return;
      final firstTicket = manual.ticketIds.isNotEmpty
          ? manual.ticketIds.first
          : manual.ticketId;
      if (firstTicket != null && firstTicket.isNotEmpty) {
        context.go('/tickets/$firstTicket');
      } else {
        context.go('/iswim');
      }
    } on AssignmentException catch (e) {
      if (mounted) AppFeedback.error(context, e.message);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      // The manual lives in a collection the deployed rules must know about.
      AppFeedback.error(
        context,
        e.code == 'permission-denied'
            ? 'Firestore refused the write. Deploy the latest rules first: '
                  'firebase deploy --only firestore:rules'
            : AppFeedback.describe(e),
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Send ${_assignments.length} '
          '${_assignments.length == 1 ? 'assignment' : 'assignments'} to City '
          'Hall?',
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmRow('Manual', _title.text.trim()),
                for (var i = 0; i < _assignments.length; i++) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${_letter(i)} · ${_assignments[i].driverName}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                  _confirmRow('Plate', _assignments[i].truck.plateNumber),
                  _confirmRow('Areas', _assignments[i].routeNames.join(' · ')),
                  _confirmRow(
                    'Schedule',
                    '${_assignments[i].daysLabel} · '
                        '${_assignments[i].startLabel} · '
                        '${_assignments[i].recurrence.label}',
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Submitting generates one trip ticket per driver. They stay '
                  'covered by a "waiting for City Hall approval" screen until '
                  'the DSQC signs them.',
                  style: TextStyle(fontSize: 10.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
            child: const Text('Submit manual'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _step == 0 ? _buildAssignStep() : _buildReviewStep(),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _handleBack,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 38,
                  width: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ISWIM · MANUAL',
                      style: EcoType.eyebrow(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _step == 0 ? 'Assign drivers' : 'Review manual',
                      style: EcoType.cardTitleLarge(
                        context,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StepBar(step: _step),
        ],
      ),
    );
  }

  Widget _buildAssignStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionLabel('MANUAL TITLE'),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Zone 3 weekly collection schedule',
            isDense: true,
          ),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('THIS WEEK AT A GLANCE'),
        const SizedBox(height: 8),
        _WeekGlance(assignments: _assignments),
        const SizedBox(height: 20),
        Row(
          children: [
            const _SectionLabel('ASSIGNMENTS'),
            const Spacer(),
            Text(
              '${_assignments.length} added',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_assignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sage),
            ),
            child: const Text(
              'No drivers yet. Add an assignment and its letter lands on the '
              'week above.',
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          )
        else
          for (var i = 0; i < _assignments.length; i++) ...[
            _AssignmentCard(
              index: i,
              assignment: _assignments[i],
              onTap: () => _openEditor(index: i),
              onRemove: () => _remove(i),
            ),
            if (i < _assignments.length - 1) const SizedBox(height: 8),
          ],
        const SizedBox(height: 10),
        _AddAssignmentButton(
          onTap: _loadingDrivers ? null : () => _openEditor(),
        ),
        if (_loadingDrivers) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionLabel('MANUAL TITLE'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Text(
            _title.text.trim().isEmpty ? 'Collection manual' : _title.text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const _SectionLabel('ASSIGNMENTS'),
            const Spacer(),
            Text(
              '${_assignments.length} '
              '${_assignments.length == 1 ? 'driver' : 'drivers'}',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _assignments.length; i++) ...[
          _ReviewAssignmentCard(index: i, assignment: _assignments[i]),
          if (i < _assignments.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 18),
        const _SectionLabel('ROUTE MAP'),
        const SizedBox(height: 8),
        ManualRouteMap(
          height: 220,
          groups: [
            for (var i = 0; i < _assignments.length; i++)
              ManualRouteGroup(
                areas: _assignments[i].routes,
                color: _letterColor(i),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text(
              'Generate manual (PDF)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.sage),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Submitting generates one trip ticket per driver. The schedule stays '
          'covered by a "waiting for City Hall approval" screen until the DSQC '
          'signs every ticket.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final review = _step == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.sage)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: _busy ? null : _handleBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.sage),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : review
                    ? (_assignments.isEmpty
                          ? null
                          : () => setState(() => _step = 1))
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        review
                            ? (_assignments.isEmpty
                                  ? 'Review assignments'
                                  : 'Review ${_assignments.length} '
                                        '${_assignments.length == 1 ? 'assignment' : 'assignments'}')
                            : 'Submit manual',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Step bar
// -----------------------------------------------------------------------------

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(number: 1, label: 'Drivers & routes', active: step >= 0),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: step >= 1 ? AppColors.primary : AppColors.sage,
          ),
        ),
        _StepDot(number: 2, label: 'Review', active: step >= 1),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 20,
          width: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary : Colors.transparent,
            border: Border.all(color: color),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Week at a glance
// -----------------------------------------------------------------------------

class _WeekGlance extends StatelessWidget {
  const _WeekGlance({required this.assignments});

  final List<_DraftAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    // One row per start time actually in use. A custom time gets its own row
    // instead of being pushed into the 8 AM or 6 PM slot.
    final times = <String>{for (final a in assignments) a.startLabel};
    final rows = times.isEmpty ? const ['08:00', '18:00'] : (times.toList()..sort());
    final cells = <String, int>{};
    for (var i = 0; i < assignments.length; i++) {
      for (final day in assignments[i].days) {
        cells.putIfAbsent('$day-${assignments[i].startLabel}', () => i);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 46),
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Center(
                    child: Text(
                      manualDayLabel(day),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final row in rows) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    _clockLabel(row),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: Center(
                      child: _GlanceCell(index: cells['$day-$row']),
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

class _GlanceCell extends StatelessWidget {
  const _GlanceCell({this.index});

  final int? index;

  @override
  Widget build(BuildContext context) {
    final value = index;
    if (value == null) {
      return Container(
        height: 24,
        width: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.sage,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      );
    }
    return Container(
      height: 24,
      width: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _letterColor(value),
      ),
      child: Text(
        _letter(value),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Assignment cards
// -----------------------------------------------------------------------------

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.index,
    required this.assignment,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final _DraftAssignment assignment;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              _LetterBadge(index: index),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            assignment.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PlateBadge(plate: assignment.truck.plateNumber),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${assignment.daysLabel} · ${assignment.startLabel}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${assignment.routes.length}/${assignment.maxRoutes} '
                      'areas · ${assignment.routeNames.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.4,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${assignment.recurrence.label} · '
                      '${assignment.validityLabel}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.moss,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove assignment',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewAssignmentCard extends StatelessWidget {
  const _ReviewAssignmentCard({required this.index, required this.assignment});

  final int index;
  final _DraftAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LetterBadge(index: index),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  assignment.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              _PlateBadge(plate: assignment.truck.plateNumber),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final area in assignment.routes)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: Text(
                    area.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${assignment.daysLabel} · ${assignment.startLabel} · '
            '${assignment.recurrence.label}',
            style: const TextStyle(
              fontSize: 10,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${assignment.truck.wheelerLabel} · '
            '${assignment.truck.bodyType} · '
            '${assignment.routes.length}/${assignment.maxRoutes} areas',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _letterColor(index),
      ),
      child: Text(
        _letter(index),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        plate,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.forest,
        ),
      ),
    );
  }
}

class _AddAssignmentButton extends StatelessWidget {
  const _AddAssignmentButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 17, color: AppColors.forest),
              const SizedBox(width: 6),
              Text(
                'Add assignment',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: onTap == null ? AppColors.inkMuted : AppColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: AppColors.inkMuted,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Add / edit assignment sheet
// -----------------------------------------------------------------------------

class _AssignmentSheet extends StatefulWidget {
  const _AssignmentSheet({
    required this.accounts,
    required this.trucks,
    required this.others,
    this.existing,
  });

  final List<_DriverOption> accounts;
  final List<GarbageTruck> trucks;
  final List<_DraftAssignment> others;
  final _DraftAssignment? existing;

  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  String? _driverKey;
  String? _truckId;
  final Set<String> _routes = {};
  final Set<int> _days = {1, 3, 5};
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  ManualRecurrence _recurrence = ManualRecurrence.weekly;
  bool _routesOpen = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _driverKey = existing.driverId.isNotEmpty
        ? 'uid:${existing.driverId}'
        : 'name:${existing.driverName}';
    _routes.addAll(existing.routeNames);
    _days
      ..clear()
      ..addAll(existing.days);
    _start = existing.startTime;
    _recurrence = existing.recurrence;
    _truckId = existing.truck.id;
  }

  /// The sheet's own option list, with the edited row kept even when its
  /// account or roster name is no longer in the live list.
  List<_DriverOption> get _options {
    final options = [...widget.accounts];
    final key = _driverKey;
    final existing = widget.existing;
    if (key != null && !options.any((option) => option.key == key)) {
      if (existing != null) {
        options.add(
          _DriverOption(
            uid: existing.driverId,
            name: existing.driverName,
            truckId: existing.truck.id,
          ),
        );
      }
    }
    return options;
  }

  _DriverOption? get _selected {
    final key = _driverKey;
    if (key == null) return null;
    for (final option in _options) {
      if (option.key == key) return option;
    }
    return null;
  }

  GarbageTruck? get _truck {
    final id = _truckId;
    if (id == null) return null;
    for (final truck in widget.trucks) {
      if (truck.id == id) return truck;
    }
    final existing = widget.existing;
    if (existing != null && existing.truck.id == id) return existing.truck;
    return null;
  }

  /// Every plate ISWIM can put this driver on. A newly added truck is listed
  /// here with a NEW tag, so the manual is where the pairing happens.
  List<GarbageTruck> get _truckOptions {
    final options = [...widget.trucks];
    final existing = widget.existing;
    if (existing != null && !options.any((t) => t.id == existing.truck.id)) {
      options.add(existing.truck);
    }
    options.sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
    return options;
  }

  /// The plate already linked to a driver account, if there is one.
  GarbageTruck? _linkedTruck(_DriverOption option) {
    for (final truck in widget.trucks) {
      if (option.truckId != null && truck.id == option.truckId) return truck;
    }
    final name = option.name.trim().toLowerCase();
    for (final truck in widget.trucks) {
      if (truck.driverName.trim().toLowerCase() == name) return truck;
    }
    return null;
  }

  int get _maxRoutes {
    final truck = _truck;
    return truck == null ? 0 : maxRoutesForWheelers(truck.wheelers);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Areas another row already covers at a start time this one would clash
  /// with, mapped to who holds them. An area can only be covered once per
  /// slot, so these cannot be picked.
  Map<String, String> get _takenAreas {
    final taken = <String, String>{};
    final start = _startLabel(_start);
    for (final other in widget.others) {
      if (!other.days.any(_days.contains)) continue;
      if (!manualSlotsClash(other.startLabel, start)) continue;
      final by = '${other.driverName} · ${other.startLabel}';
      for (final name in other.routeNames) {
        taken.putIfAbsent(name, () => by);
      }
    }
    return taken;
  }

  void _toggleRoute(String name) {
    if (_routes.contains(name)) {
      setState(() => _routes.remove(name));
      return;
    }
    final takenBy = _takenAreas[name];
    if (takenBy != null) {
      _toast('$name is already covered by $takenBy.');
      return;
    }
    if (_maxRoutes == 0) {
      _toast('Pick a truck first.');
      return;
    }
    if (_routes.length >= _maxRoutes) {
      setState(() => _routesOpen = true);
      _toast('Limit reached. Remove one route to pick another.');
      return;
    }
    setState(() => _routes.add(name));
  }

  void _selectDriver(String? value) {
    if (value == null) return;
    setState(() {
      _driverKey = value;
      final option = _selected;
      final linked = option == null ? null : _linkedTruck(option);
      // A driver who already holds a plate keeps it; a new driver starts on
      // the plate ISWIM picks next.
      if (linked != null) _truckId = linked.id;
      _trimRoutes();
    });
  }

  void _selectTruck(String? value) {
    if (value == null) return;
    setState(() {
      _truckId = value;
      _trimRoutes();
    });
  }

  /// Keeps the picked areas inside the new truck's limit.
  void _trimRoutes() {
    final max = _maxRoutes;
    while (_routes.length > max) {
      _routes.remove(_routes.last);
    }
  }

  bool _sameDays(Set<int> days) =>
      _days.length == days.length && _days.containsAll(days);

  String? get _conflict {
    final option = _selected;
    final truck = _truck;
    if (option == null || truck == null || _days.isEmpty) return null;
    final start = _startLabel(_start);
    for (final other in widget.others) {
      if (!other.days.any(_days.contains)) continue;
      final sameDriver = manualSameDriver(
        driverId: option.uid,
        driverName: option.name,
        otherDriverId: other.driverId,
        otherDriverName: other.driverName,
      );
      final sameTruck = other.truck.id == truck.id;
      if (!sameDriver && !sameTruck) continue;
      // A driver needs six hours between shifts; a plate cannot be on two
      // routes at the same moment.
      final clash = sameDriver
          ? manualSlotsClash(other.startLabel, start)
          : other.startLabel == start;
      if (!clash) continue;
      final shared = ([
        ..._days,
      ]..sort()).where(other.days.contains).map(manualDayLabel).join(', ');
      if (sameDriver) {
        return '${other.driverName} already starts on $shared at '
            '${other.startLabel}. Leave 6 hours between shifts.';
      }
      return 'Plate ${other.truck.plateNumber} is already out on $shared at '
          '${other.startLabel}.';
    }
    return null;
  }

  static String _startLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static String _prettyTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  void _save({required bool addAnother}) {
    final option = _selected;
    final truck = _truck;
    if (option == null) {
      _toast('Pick the driver for this assignment.');
      return;
    }
    if (truck == null) {
      _toast('Pick a truck for this driver.');
      return;
    }
    if (_routes.isEmpty) {
      _toast('Pick at least one area.');
      return;
    }
    if (_days.isEmpty) {
      _toast('Pick at least one collection day.');
      return;
    }
    final conflict = _conflict;
    if (conflict != null) {
      _toast(conflict);
      return;
    }
    // The day or start time may have moved after the areas were picked.
    final taken = _takenAreas;
    for (final name in _routes) {
      final takenBy = taken[name];
      if (takenBy == null) continue;
      _toast('$name is already covered by $takenBy. Remove it first.');
      return;
    }

    final draft = _DraftAssignment(
      driverId: option.uid,
      driverName: option.name,
      truck: truck,
      routes: manualAreasFor(_routes),
      days: {..._days},
      startTime: _start,
      recurrence: _recurrence,
    );
    Navigator.of(
      context,
    ).pop(_SheetResult(draft: draft, addAnother: addAnother));
  }

  @override
  Widget build(BuildContext context) {
    final truck = _truck;
    final conflict = _conflict;
    final taken = _takenAreas;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existing == null
                              ? 'Add assignment'
                              : 'Edit assignment',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'One driver per row. Add as many rows as the manual '
                          'needs.',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('QUICK FILL DAYS'),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _QuickFill(
                          label: 'Mon · Wed · Fri',
                          selected: _sameDays(const {1, 3, 5}),
                          onTap: () => setState(
                            () => _days
                              ..clear()
                              ..addAll(const {1, 3, 5}),
                          ),
                        ),
                        _QuickFill(
                          label: 'Tue · Thu · Sat',
                          selected: _sameDays(const {2, 4, 6}),
                          onTap: () => setState(
                            () => _days
                              ..clear()
                              ..addAll(const {2, 4, 6}),
                          ),
                        ),
                        _QuickFill(
                          label: 'Weekdays',
                          selected: _sameDays(const {1, 2, 3, 4, 5}),
                          onTap: () => setState(
                            () => _days
                              ..clear()
                              ..addAll(const {1, 2, 3, 4, 5}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _driverKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Driver',
                        isDense: true,
                      ),
                      items: [
                        for (final option in _options)
                          DropdownMenuItem(
                            value: option.key,
                            child: Row(
                              children: [
                                _DriverDot(name: option.name),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    option.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: _selectDriver,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String?>(_truckId),
                            initialValue: _truckId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Truck',
                              hintText: 'Assign a plate',
                              isDense: true,
                            ),
                            items: [
                              for (final option in _truckOptions)
                                DropdownMenuItem(
                                  value: option.id,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${option.plateNumber} · '
                                          '${option.wheelerLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      if (option.isNew) ...[
                                        const SizedBox(width: 5),
                                        const _NewTag(),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: _selectTruck,
                          ),
                        ),
                        if (truck != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.sage),
                            ),
                            child: Text(
                              'max $_maxRoutes routes',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Submitting the manual pairs this driver with the plate.',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.4,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_routes.isNotEmpty) ...[
                      ManualRouteMap(
                        height: 160,
                        groups: [
                          ManualRouteGroup(
                            areas: manualAreasFor(_routes),
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _routesOpen
                              ? AppColors.primary
                              : AppColors.sage,
                        ),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () =>
                                setState(() => _routesOpen = !_routesOpen),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                11,
                                10,
                                11,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Routes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_routes.length} of $_maxRoutes selected',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Icon(
                                    _routesOpen
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: AppColors.inkMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_routes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final name in _routes)
                                      _SelectedAreaChip(
                                        name: name,
                                        onRemove: () => setState(
                                          () => _routes.remove(name),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (_routesOpen) ...[
                            const Divider(height: 1),
                            Container(
                              color: AppColors.mint.withValues(alpha: 0.55),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Choose up to $_maxRoutes areas for a '
                                      '${truck?.wheelerLabel ?? 'truck'}',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_routes.length}/$_maxRoutes',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 250,
                              child: ListView.builder(
                                itemCount: kManualAreas.length,
                                itemBuilder: (context, index) {
                                  final area = kManualAreas[index];
                                  final selected = _routes.contains(area.name);
                                  final takenBy = taken[area.name];
                                  final disabled =
                                      takenBy != null ||
                                      (!selected &&
                                          _routes.length >= _maxRoutes);
                                  return _AreaCheckRow(
                                    name: area.name,
                                    selected: selected,
                                    disabled: disabled,
                                    takenBy: takenBy,
                                    onTap: () => _toggleRoute(area.name),
                                  );
                                },
                              ),
                            ),
                            if (_routes.length >= _maxRoutes)
                              Container(
                                width: double.infinity,
                                color: AppColors.cream,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 13,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Limit reached. Remove one route to '
                                        'pick another.',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.warning.withValues(
                                            alpha: 0.95,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const SizedBox(
                          width: 44,
                          child: Text(
                            'Days',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        for (var day = 1; day <= 7; day++) ...[
                          _DayToggle(
                            day: day,
                            selected: _days.contains(day),
                            onTap: () => setState(() {
                              if (!_days.remove(day)) _days.add(day);
                            }),
                          ),
                          if (day < 7) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 44,
                          child: Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        _TimePill(
                          label: '8:00 AM',
                          selected:
                              _start == const TimeOfDay(hour: 8, minute: 0),
                          onTap: () => setState(
                            () => _start = const TimeOfDay(hour: 8, minute: 0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TimePill(
                          label: '6:00 PM',
                          selected:
                              _start == const TimeOfDay(hour: 18, minute: 0),
                          onTap: () => setState(
                            () => _start = const TimeOfDay(hour: 18, minute: 0),
                          ),
                        ),
                        if (_start != const TimeOfDay(hour: 8, minute: 0) &&
                            _start != const TimeOfDay(hour: 18, minute: 0)) ...[
                          const SizedBox(width: 6),
                          _TimePill(
                            label: _prettyTime(_start),
                            selected: true,
                            onTap: _pickTime,
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          onPressed: _pickTime,
                          tooltip: 'Pick another time',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A driver can take a second area on the same day only '
                      'with 6 hours between starts — 8:00 AM and 6:00 PM are '
                      'fine, 8:00 AM and 10:00 AM are not.',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.4,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ManualRecurrence>(
                      initialValue: _recurrence,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Repeats',
                        isDense: true,
                      ),
                      items: [
                        for (final value in ManualRecurrence.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              value.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _recurrence = value ?? _recurrence),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Weekly keeps running until cancelled · monthly lasts '
                      'one month · yearly lasts one year.',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.4,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Valid until '
                      '${dateLabel(manualValidUntil(recurrence: _recurrence, from: DateTime.now()))}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: conflict == null
                            ? AppColors.mint
                            : AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: conflict == null
                              ? AppColors.sage
                              : AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            conflict == null
                                ? Icons.check_circle_outline_rounded
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: conflict == null
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              conflict ?? 'No conflicts with other assignments',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: conflict == null
                                    ? AppColors.forest
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.sage)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.existing == null) ...[
                    SizedBox(
                      height: 42,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _save(addAnother: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(color: AppColors.sage),
                        ),
                        child: const Text(
                          'Save & add another',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _save(addAnother: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                      ),
                      child: Text(
                        widget.existing == null
                            ? 'Save assignment'
                            : 'Save changes',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickFill extends StatelessWidget {
  const _QuickFill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A selected chip would otherwise take the theme's white
    // `secondaryLabelStyle` and vanish on the pale mint fill.
    final ink = selected ? AppColors.forest : AppColors.textDark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.mint,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      checkmarkColor: AppColors.forest,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.sage),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _DriverDot extends StatelessWidget {
  const _DriverDot({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return Container(
      height: 22,
      width: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.forest,
      ),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SelectedAreaChip extends StatelessWidget {
  const _SelectedAreaChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 9, right: 2),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaCheckRow extends StatelessWidget {
  const _AreaCheckRow({
    required this.name,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.takenBy,
  });

  final String name;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  /// Who already covers this area at the chosen time, when it is taken.
  final String? takenBy;

  @override
  Widget build(BuildContext context) {
    final holder = takenBy;
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: disabled ? null : (_) => onTap(),
              activeColor: AppColors.forest,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 10.5,
                  color: disabled ? AppColors.inkMuted : AppColors.textDark,
                ),
              ),
            ),
            if (holder != null)
              Flexible(
                child: Text(
                  holder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 30,
        width: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sage,
          ),
        ),
        child: Text(
          manualDayLabel(day),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sage,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.forest : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
