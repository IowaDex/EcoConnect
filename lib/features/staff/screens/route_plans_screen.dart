import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/route_plan.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/route_service.dart';
import 'stop_picker_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

/// Staff dispatch board: assign one collection run per driver per day.
/// Drivers can only activate a route that exists here (or start an ad-hoc run).
class RoutePlansScreen extends StatefulWidget {
  const RoutePlansScreen({super.key});

  @override
  State<RoutePlansScreen> createState() => _RoutePlansScreenState();
}

class _RoutePlansScreenState extends State<RoutePlansScreen> {
  final _routeService = RouteService();
  final _authService = AuthService();
  final _zoneController = TextEditingController();
  List<RouteStop> _stops = [];

  List<Map<String, dynamic>> _drivers = [];
  String? _driverId;
  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _loadingDrivers = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final users = await _authService.getAllUsers();
      final drivers = users
          .where((u) =>
              u['role'] == 'driver' &&
              (u['accountStatus'] ?? 'active') == 'active')
          .toList();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _driverId = drivers.isEmpty ? null : drivers.first['uid'] as String?;
        _loadingDrivers = false;
      });
      _prefillZone(_driverId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDrivers = false);
      _toast('Could not load drivers: $e', isError: true);
    }
  }

  void _prefillZone(String? driverId) {
    if (driverId == null) return;
    final driver = _drivers.firstWhere(
      (d) => d['uid'] == driverId,
      orElse: () => const {},
    );
    final barangay = (driver['barangay'] as String?)?.trim();
    if (barangay != null && barangay.isNotEmpty) {
      _zoneController.text = barangay;
    }
  }

  String _timeKey(TimeOfDay time) =>
      routeTimeKey(DateTime(2000, 1, 1, time.hour, time.minute));

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _assign() async {
    final driverId = _driverId;
    if (driverId == null) {
      _toast('No approved driver accounts yet', isError: true);
      return;
    }
    final zone = _zoneController.text.trim();
    if (zone.isEmpty) {
      _toast('Enter the zone this driver will cover', isError: true);
      return;
    }
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (endMinutes <= startMinutes) {
      _toast('The window must end after it starts', isError: true);
      return;
    }

    final driver = _drivers.firstWhere(
      (d) => d['uid'] == driverId,
      orElse: () => const {},
    );
    final name =
        (driver['name'] ?? driver['displayName'] ?? 'Collector').toString();

    setState(() => _busy = true);
    try {
      await _routeService.createPlan(
        driverId: driverId,
        driverName: name,
        zone: zone,
        date: DateTime.now(),
        windowStart: _timeKey(_start),
        windowEnd: _timeKey(_end),
        stops: _stops,
        createdBy: context.read<AuthProvider>().currentUser?.uid,
      );
      if (!mounted) return;
      setState(() => _stops = []);
      _toast('Route assigned to $name');
    } catch (e) {
      _toast('Could not assign the route: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickStops() async {
    final result = await Navigator.of(context).push<List<RouteStop>>(
      MaterialPageRoute(
        builder: (_) => StopPickerScreen(
          initialStops: _stops,
          zone: _zoneController.text.trim(),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _stops = result);
  }

  Future<void> _cancelPlan(RoutePlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this assignment?'),
        content: Text(
          '${plan.driverName} will no longer be able to activate the '
          '${plan.zone} run for ${plan.windowLabel}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel route'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _routeService.cancelPlan(plan.id);
      _toast('Assignment cancelled');
    } catch (e) {
      _toast('Could not cancel: $e', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.forest,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/admin-dashboard'),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  Text(
                    routeDateLabel(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Route assignments',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign one collection run per driver. Drivers can only '
                'activate what you schedule here.',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 18),
              _AssignCard(
                drivers: _drivers,
                loading: _loadingDrivers,
                driverId: _driverId,
                zoneController: _zoneController,
                stops: _stops,
                start: _start,
                end: _end,
                busy: _busy,
                onDriverChanged: (value) {
                  setState(() => _driverId = value);
                  _prefillZone(value);
                },
                onPickStart: () => _pickTime(isStart: true),
                onPickEnd: () => _pickTime(isStart: false),
                onPickStops: _pickStops,
                onRemoveStop: (index) =>
                    setState(() => _stops = [..._stops]..removeAt(index)),
                onAssign: _assign,
              ),
              const SizedBox(height: 22),
              const Text(
                'Today’s runs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<RoutePlan>>(
                stream: _routeService.watchPlansForToday(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _EmptyPlans(
                      message: 'Could not load today’s assignments. '
                          'Check that the Firestore rules are published.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final plans = snapshot.data ?? const <RoutePlan>[];
                  if (plans.isEmpty) {
                    return const _EmptyPlans(
                      message: 'No routes scheduled for today yet.',
                    );
                  }
                  return Column(
                    children: [
                      for (final plan in plans)
                        _PlanTile(
                          plan: plan,
                          onCancel: plan.status == RoutePlanStatus.scheduled
                              ? () => _cancelPlan(plan)
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignCard extends StatelessWidget {
  const _AssignCard({
    required this.drivers,
    required this.loading,
    required this.driverId,
    required this.zoneController,
    required this.stops,
    required this.start,
    required this.end,
    required this.busy,
    required this.onDriverChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickStops,
    required this.onRemoveStop,
    required this.onAssign,
  });

  final List<Map<String, dynamic>> drivers;
  final bool loading;
  final String? driverId;
  final TextEditingController zoneController;
  final List<RouteStop> stops;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool busy;
  final ValueChanged<String?> onDriverChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onPickStops;
  final ValueChanged<int> onRemoveStop;
  final VoidCallback onAssign;

  String _label(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New assignment',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (drivers.isEmpty)
            const Text(
              'No approved driver accounts yet. Approve a driver from '
              'Pending accounts first.',
              style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.danger),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey(driverId),
              initialValue: driverId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Driver',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final driver in drivers)
                  DropdownMenuItem(
                    value: driver['uid'] as String?,
                    child: Text(
                      (driver['name'] ?? driver['displayName'] ?? 'Driver')
                          .toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
              onChanged: onDriverChanged,
            ),
          const SizedBox(height: 10),
          TextField(
            controller: zoneController,
            decoration: const InputDecoration(
              labelText: 'Zone / barangay',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Window start',
                  value: _label(start),
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeField(
                  label: 'Window end',
                  value: _label(end),
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StopsField(
            stops: stops,
            onPick: onPickStops,
            onRemove: onRemoveStop,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Assign route',
            loading: busy,
            onPressed: drivers.isEmpty ? null : onAssign,
            height: 44,
          ),
        ],
      ),
    );
  }
}

class _StopsField extends StatelessWidget {
  const _StopsField({
    required this.stops,
    required this.onPick,
    required this.onRemove,
  });

  final List<RouteStop> stops;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 14, color: AppColors.moss),
              const SizedBox(width: 6),
              const Text(
                'Route stops',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                stops.length.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.moss,
                ),
              ),
            ],
          ),
          if (stops.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No stops yet — residents will only see the live truck.',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  for (var i = 0; i < stops.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            height: 16,
                            width: 16,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.forest,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              (i + 1).toString(),
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              stops[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => onRemove(i),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close_rounded,
                                  size: 12, color: AppColors.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.map_outlined, size: 14),
            label: Text(
              stops.isEmpty ? 'Pick stops on map' : 'Edit stops on map',
              style: const TextStyle(fontSize: 10.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.sage),
              minimumSize: const Size.fromHeight(34),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        child: Row(
          children: [
            Text(value, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            const Icon(Icons.schedule_rounded,
                size: 14, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, this.onCancel});

  final RoutePlan plan;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plan.driverName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (plan.adHoc)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ad-hoc',
                          style: TextStyle(
                              fontSize: 7.5, color: AppColors.forest),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.zone} · ${plan.windowLabel} · ${plan.stopsLabel}',
                  style: const TextStyle(
                      fontSize: 9.5, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: plan.status.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: plan.status.color.withValues(alpha: 0.6)),
            ),
            child: Text(
              plan.status.label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: plan.status == RoutePlanStatus.scheduled
                    ? AppColors.forest
                    : plan.status.color,
              ),
            ),
          ),
          if (onCancel != null)
            IconButton(
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.inkMuted),
              tooltip: 'Cancel assignment',
            ),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.45,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}
