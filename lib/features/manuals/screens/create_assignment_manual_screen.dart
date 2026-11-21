import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../../tickets/models/trip_ticket.dart';
import '../services/assignment_manual_service.dart';
import '../services/manual_pdf.dart';
import 'manual_route_picker_screen.dart';

/// A driver account Iswim can put on a manual.
class _DriverOption {
  const _DriverOption({required this.uid, required this.name, this.truckId});

  final String uid;
  final String name;
  final String? truckId;

  String get key => uid.isNotEmpty ? 'uid:$uid' : 'name:$name';
}

/// Iswim builds the collection manual City Hall asked for.
///
/// One driver, the truck that comes with him, up to three routes, the days he
/// runs and a single start time. Submitting it generates the trip ticket that
/// City Hall signs; until then the schedule is not valid.
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
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();

  /// The streets picked on the map, in tap order.
  final List<ManualRoutePoint> _routes = [];

  List<_DriverOption> _accounts = const [];
  List<GarbageTruck> _trucks = const [];
  String? _driverKey;
  final Set<int> _days = {1, 3, 5};
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  ManualRecurrence _recurrence = ManualRecurrence.weekly;
  bool _busy = false;
  bool _loadingDrivers = true;

  @override
  void initState() {
    super.initState();
    _title.text = widget.requestTitle.trim();
    _loadDrivers();
  }

  @override
  void dispose() {
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

  _DriverOption? get _selected {
    final key = _driverKey;
    if (key == null) return null;
    for (final option in _options()) {
      if (option.key == key) return option;
    }
    return null;
  }

  GarbageTruck? get _truck {
    final driver = _selected;
    if (driver == null) return null;
    for (final truck in _trucks) {
      if (driver.truckId != null && truck.id == driver.truckId) return truck;
      if (truck.driverName.trim().toLowerCase() ==
          driver.name.trim().toLowerCase()) {
        return truck;
      }
    }
    return null;
  }

  int get _maxRoutes {
    final truck = _truck;
    return maxRoutesForWheelers(truck?.wheelers ?? 6);
  }

  void _syncRouteFields() {
    if (_routes.length > _maxRoutes) {
      _routes.removeRange(_maxRoutes, _routes.length);
    }
  }

  /// Opens the map so the streets can be tapped instead of typed. The picked
  /// list replaces whatever was there, which is also how a route is changed.
  Future<void> _pickRoutes() async {
    final truck = _truck;
    if (truck == null) {
      AppFeedback.error(
        context,
        'Pick a driver with an assigned truck first — the truck size sets how '
        'many routes fit.',
      );
      return;
    }
    final picked = await Navigator.of(context).push<List<ManualRoutePoint>>(
      MaterialPageRoute(
        builder: (_) => ManualRoutePickerScreen(
          maxRoutes: maxRoutesForWheelers(truck.wheelers),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _routes
        ..clear()
        ..addAll(picked.take(maxRoutesForWheelers(truck.wheelers)));
    });
  }

  String get _startLabel =>
      '${_startTime.hour.toString().padLeft(2, '0')}:'
      '${_startTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  List<String> get _routeValues =>
      List<String>.unmodifiable(_routes.map((point) => point.name));

  Future<void> _exportPdf() async {
    final driver = _selected;
    final truck = _truck;
    if (driver == null || truck == null) {
      AppFeedback.error(context, 'Pick a driver with an assigned truck first.');
      return;
    }
    final saved = await exportAssignmentManualPdf(
      title: _title.text,
      driverName: driver.name,
      plateNumber: truck.plateNumber,
      wheelers: truck.wheelers,
      routes: _routeValues,
      days: [..._days]..sort(),
      startTime: _startLabel,
      recurrence: _recurrence,
      status: 'Waiting for City Hall approval',
      requestTitle: widget.requestTitle,
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
    if (!_formKey.currentState!.validate()) return;
    final driver = _selected;
    final truck = _truck;
    if (driver == null) {
      AppFeedback.error(context, 'Select the driver for this manual.');
      return;
    }
    if (truck == null) {
      AppFeedback.error(
        context,
        'That driver has no truck assigned. Pair a plate in Fleet first.',
      );
      return;
    }
    if (_days.isEmpty) {
      AppFeedback.error(context, 'Pick at least one collection day.');
      return;
    }
    final routes = _routeValues;
    if (routes.isEmpty) {
      AppFeedback.error(context, 'Pick at least one route on the map.');
      return;
    }

    final confirmed = await _confirm(driver, truck, routes);
    if (!confirmed || !mounted) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final manual = await AssignmentManualService().submit(
        title: _title.text,
        driverId: driver.uid,
        driverName: driver.name,
        truckId: truck.id,
        plateNumber: truck.plateNumber,
        wheelers: truck.wheelers,
        routes: routes,
        routePoints: List<ManualRoutePoint>.unmodifiable(_routes),
        days: [..._days]..sort(),
        startTime: _startLabel,
        recurrence: _recurrence,
        byId: user.uid,
        byName: user.displayName ?? 'Iswim',
        requestId: widget.requestId,
      );
      if (!mounted) return;
      if (manual.ticketId != null) {
        context.go('/tickets/${manual.ticketId}');
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

  Future<bool> _confirm(
    _DriverOption driver,
    GarbageTruck truck,
    List<String> routes,
  ) async {
    final days = ([..._days]..sort()).map(manualDayLabel).join(', ');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All credentials are correct?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Driver', driver.name),
            _confirmRow('Plate number', truck.plateNumber),
            _confirmRow('Truck', truck.wheelerLabel),
            _confirmRow('Routes', routes.join(' · ')),
            _confirmRow('Schedule', days),
            _confirmRow('Start time', _startLabel),
            _confirmRow('Recurrence', _recurrence.label),
            const SizedBox(height: 10),
            const Text(
              'Submitting generates a trip ticket that still needs the City '
              'Hall signature before it becomes valid.',
              style: TextStyle(fontSize: 10.5, height: 1.45),
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10.5))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'ISWIM · MANUAL',
      title: 'Create collection manual',
      subtitle: widget.requestTitle.trim().isEmpty
          ? 'Build the schedule, then send it to City Hall for approval.'
          : 'Answering: ${widget.requestTitle.trim()}',
      onBack: () => ecoBack(context, '/manual-requests'),
      body: StreamBuilder<List<GarbageTruck>>(
        stream: FleetService().watchTrucks(),
        builder: (context, snapshot) {
          _trucks = snapshot.data ?? _trucks;
          // The fleet stream can land after a driver is picked; trim any route
          // fields the smaller truck cannot take after this frame.
          if (_routes.length > _maxRoutes) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _routes.length > _maxRoutes) {
                setState(_syncRouteFields);
              }
            });
          }
          final driver = _selected;
          final truck = _truck;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _SectionLabel('MANUAL TITLE'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Zone 3 weekly collection schedule',
                    isDense: true,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Give this manual a title'
                      : null,
                ),
                const SizedBox(height: 18),
                const _SectionLabel('DRIVER AND TRUCK'),
                const SizedBox(height: 8),
                if (_loadingDrivers && _accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _driverKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Driver',
                      isDense: true,
                    ),
                    items: [
                      for (final option in _options())
                        DropdownMenuItem(
                          value: option.key,
                          child: Text(
                            option.name,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _driverKey = value;
                      _syncRouteFields();
                    }),
                    validator: (value) =>
                        value == null ? 'Select the driver' : null,
                  ),
                if (driver != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: truck == null ? AppColors.cream : AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: truck == null
                            ? AppColors.warning
                            : AppColors.sage,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          truck == null
                              ? Icons.warning_amber_rounded
                              : Icons.local_shipping_rounded,
                          size: 16,
                          color: truck == null
                              ? AppColors.warning
                              : AppColors.forest,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            truck == null
                                ? '${driver.name} has no truck assigned yet.'
                                : '${truck.plateNumber} · ${truck.wheelerLabel} · '
                                      '${truck.bodyType} · ${truck.zone}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: truck == null
                                  ? AppColors.textDark
                                  : AppColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const _SectionLabel('ROUTES'),
                    const Spacer(),
                    Text(
                      '${_routes.length}/$_maxRoutes max',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_routes.isEmpty)
                  InkWell(
                    onTap: _pickRoutes,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.sage),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: AppColors.forest,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pick the routes on the map',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tap the streets the truck covers — the names '
                                  'are filled in for you.',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    height: 1.4,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _routes.length; i++)
                        Container(
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
                                '${i + 1}. ${_routes[i].name}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forest,
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _routes.removeAt(i)),
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
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pickRoutes,
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text(
                        'Change routes on the map',
                        style: TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const _SectionLabel('SCHEDULE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(
                          manualDayLabel(day),
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        selected: _days.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sage),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 17,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 9),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start time',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  Text(
                                    _startLabel,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<ManualRecurrence>(
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
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'No end time: the driver marks each run as completed.',
                  style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: const Text(
                      'Generate mock manual (PDF)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forest,
                      side: const BorderSide(color: AppColors.sage),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: const Text(
                      'Submit manual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Submitting generates a trip ticket. It stays covered by a '
                  '"waiting for City Hall approval" screen until the DSQC signs '
                  'it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          );
        },
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
