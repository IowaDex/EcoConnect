import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/models/collection_route.dart';
import '../../../core/models/route_plan.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/route_preview_map.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _routeService = RouteService();
  StreamSubscription<CollectionRoute?>? _routeSub;
  StreamSubscription<RoutePlan?>? _planSub;
  Timer? _broadcastTimer;
  Timer? _clockTimer;

  RouteStatus _status = RouteStatus.idle;
  RoutePlan? _plan;
  String? _activePlanId;
  DateTime? _startedAt;
  bool _busy = false;
  bool _serviceUnavailable = false;

  bool get _isLive =>
      _status == RouteStatus.inTransit || _status == RouteStatus.delayed;

  String? get _uid => context.read<AuthProvider>().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final location = context.read<LocationProvider>();
    if (!location.hasLocation) await location.getCurrentLocation();
    if (!location.isTracking) location.startTracking();

    final uid = _uid;
    if (uid == null) return;

    // Mirror the server state so a reload never desyncs the dashboard from
    // what residents are actually seeing.
    _routeSub = _routeService.watchDriverRoute(uid).listen(
      (route) {
        if (!mounted) return;
        final status = route?.status ?? RouteStatus.idle;
        setState(() {
          _status = status;
          _startedAt = route?.startedAt;
          _activePlanId = route?.planId;
        });
        if (status == RouteStatus.inTransit || status == RouteStatus.delayed) {
          _startBroadcast(uid);
        } else {
          _broadcastTimer?.cancel();
          _broadcastTimer = null;
        }
      },
      onError: (_) {
        if (mounted) setState(() => _serviceUnavailable = true);
      },
    );

    // The assignment is the source of truth for *what* the driver may start.
    _planSub = _routeService.watchTodayPlan(uid).listen(
      (plan) {
        if (mounted) setState(() => _plan = plan);
      },
      onError: (_) {
        if (mounted) setState(() => _serviceUnavailable = true);
      },
    );

    // Keeps the "running for…" clock ticking without another server read.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _isLive) setState(() {});
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _planSub?.cancel();
    _broadcastTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startBroadcast(String driverId) {
    if (_broadcastTimer?.isActive ?? false) return;
    _broadcastTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final location = context.read<LocationProvider>();
      if (location.hasLocation) {
        _routeService
            .pushPosition(driverId, location.latitude!, location.longitude!)
            .catchError((_) {});
      }
    });
  }

  Future<void> _activate() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final location = context.read<LocationProvider>();
    if (!location.hasLocation) await location.getCurrentLocation();
    if (!mounted) return;

    RoutePlan? plan = _plan;
    if (plan == null) {
      plan = await _askAdHocZone();
      if (plan == null || !mounted) return;
    }
    final activePlan = plan;

    // Step 1 — pre-flight checklist. Nothing is written until this passes.
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreflightSheet(plan: activePlan),
    );
    if (confirmed != true || !mounted) return;

    // Step 2 — a late or early start is allowed, but never silent.
    var overrideWindow = false;
    if (!activePlan.isOpenAt(DateTime.now())) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Outside your shift window'),
          content: Text(
            'This route is scheduled for ${activePlan.windowLabel}. '
            'Starting now will be logged as an off-window activation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Start anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      overrideWindow = true;
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      // Step 3 — atomic activation: plan -> active, route -> inTransit.
      await _routeService.activateRoute(
        driverId: user.uid,
        driverName: user.displayName ?? 'Collector',
        phone: user.phone,
        planId: activePlan.id,
        latitude: location.latitude,
        longitude: location.longitude,
        overrideWindow: overrideWindow,
      );
      _startBroadcast(user.uid);
      if (mounted) {
        setState(() {
          _status = RouteStatus.inTransit;
          _startedAt = DateTime.now();
          _activePlanId = activePlan.id;
        });
      }
      _toast('Route activated — residents can see you now');
    } on RouteActivationException catch (e) {
      _toast(e.message, isError: true);
    } catch (e) {
      _fail('start your route', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// No staff assignment today: the driver may still run, but the zone is
  /// captured explicitly and the run is flagged as ad-hoc for auditing.
  Future<RoutePlan?> _askAdHocZone() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;

    final controller = TextEditingController(text: user.barangay ?? '');
    final formKey = GlobalKey<FormState>();

    final zone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start an ad-hoc route'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No route was assigned to you today. Confirm the zone you are '
                'covering — this run is logged as ad-hoc so staff can review it.',
                style: TextStyle(fontSize: 11.5, height: 1.45),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Zone / barangay',
                  isDense: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the zone you will cover'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (zone == null || zone.isEmpty) return null;

    final now = DateTime.now();
    try {
      return await _routeService.createPlan(
        driverId: user.uid,
        driverName: user.displayName ?? 'Collector',
        zone: zone,
        date: now,
        windowStart: routeTimeKey(now),
        windowEnd: routeTimeKey(now.add(const Duration(hours: 4))),
        adHoc: true,
        createdBy: user.uid,
      );
    } catch (e) {
      _fail('open an ad-hoc route', e);
      return null;
    }
  }

  Future<void> _changeStatus(RouteStatus status) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final previous = _status;
    setState(() => _status = status);
    try {
      await _routeService.setStatus(user.uid, status);
    } catch (e) {
      if (mounted) setState(() => _status = previous);
      _fail('update your status', e);
    }
  }

  Future<void> _endRoute() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End collection route?'),
        content: const Text(
          'Residents will stop seeing your live location immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End route'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final startedAt = _startedAt;
    try {
      await _routeService.endRoute(user.uid, planId: _activePlanId);
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      if (!mounted) return;
      // Stop streaming GPS once the run is over — no route means no reason
      // to keep the device radio busy.
      context.read<LocationProvider>().stopTracking();
      setState(() {
        _status = RouteStatus.idle;
        _startedAt = null;
        _activePlanId = null;
      });
      if (startedAt != null) _showSummary(startedAt);
    } catch (e) {
      _fail('end your route', e);
    }
  }

  Future<void> _showSummary(DateTime startedAt) async {
    final duration = DateTime.now().difference(startedAt);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Route complete'),
        content: Text(
          'You were on the road for ${_formatDuration(duration)}. '
          'Your assignment is marked completed and residents no longer see '
          'your location.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes}m';
  }

  void _fail(String action, Object error) {
    final raw = error.toString();
    final denied = raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED') ||
        raw.contains('insufficient permissions');
    _toast(
      denied
          ? 'Could not $action: Firestore permissions are blocking writes. '
              'Ask barangay staff to publish the updated rules.'
          : 'Could not $action: $raw',
      isError: true,
    );
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'If your route is running, end it first so residents stop seeing '
          'your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = _uid;
    _broadcastTimer?.cancel();
    if (uid != null && _isLive) {
      try {
        await _routeService.endRoute(uid, planId: _activePlanId);
      } catch (_) {
        // Best effort — never trap the driver in a broken session.
      }
    }
    if (!mounted) return;
    context.read<LocationProvider>().stopTracking();
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationProvider>();
    final user = auth.currentUser;

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
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Driver dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.displayName ?? 'Collector',
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 20),
              if (_serviceUnavailable) ...[
                const _ServiceWarning(),
                const SizedBox(height: 14),
              ],
              _AssignmentCard(
                plan: _plan,
                status: _status,
                startedAt: _startedAt,
                busy: _busy,
                onActivate: _activate,
                onEnd: _endRoute,
              ),
              if (_plan != null) ...[
                const SizedBox(height: 14),
                _RouteStopsCard(
                  plan: _plan!,
                  truck: location.hasLocation
                      ? LatLng(location.latitude!, location.longitude!)
                      : null,
                ),
              ],
              if (_isLive) ...[
                const SizedBox(height: 16),
                const Text(
                  'Update status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final status in [
                      RouteStatus.inTransit,
                      RouteStatus.delayed,
                    ])
                      _StatusChip(
                        label: status.label,
                        selected: _status == status,
                        color: status.color,
                        onTap: () => _changeStatus(status),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _LocationCard(
                location: location,
                isLive: _isLive,
                onBroadcast: () async {
                  final driver = user;
                  await location.getCurrentLocation();
                  if (driver == null || !location.hasLocation || !_isLive) {
                    return;
                  }
                  try {
                    await _routeService.pushPosition(
                        driver.uid, location.latitude!, location.longitude!);
                    _toast('Location broadcast to residents');
                  } catch (e) {
                    _fail('broadcast your location', e);
                  }
                },
              ),
              const SizedBox(height: 16),
              const _TipCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceWarning extends StatelessWidget {
  const _ServiceWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2B441)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFB26A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live tracking is unavailable. The collection service is not '
              'accepting requests yet — ask barangay staff to publish the '
              'Firestore rules.',
              style: TextStyle(
                fontSize: 9.5,
                height: 1.5,
                color: const Color(0xFF8A5200).withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.plan,
    required this.status,
    required this.startedAt,
    required this.busy,
    required this.onActivate,
    required this.onEnd,
  });

  final RoutePlan? plan;
  final RouteStatus status;
  final DateTime? startedAt;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onEnd;

  bool get _isLive =>
      status == RouteStatus.inTransit || status == RouteStatus.delayed;

  @override
  Widget build(BuildContext context) {
    final badgeLabel =
        _isLive ? status.label : plan?.status.label ?? 'Not scheduled';
    final badgeColor =
        _isLive ? status.color : plan?.status.color ?? Colors.white70;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.7)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.local_shipping_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isLive ? 'Assigned zone' : 'Today’s assignment',
            style: const TextStyle(fontSize: 9, color: Color(0xB3FFFFFF)),
          ),
          const SizedBox(height: 2),
          Text(
            plan?.zone ?? 'No zone assigned',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (plan != null)
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: Color(0xB3FFFFFF)),
                const SizedBox(width: 5),
                Text(
                  plan!.windowLabel,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.place_outlined,
                    size: 13, color: Color(0xB3FFFFFF)),
                const SizedBox(width: 5),
                Text(
                  plan!.stopsLabel,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xCCFFFFFF)),
                ),
              ],
            )
          else
            Text(
              'Barangay staff has not scheduled a run for you today.',
              style: TextStyle(
                fontSize: 10,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          if (_isLive && startedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Running for ${_runningFor(startedAt!)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.lime,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_isLive)
            PrimaryButton(
              label: 'End collection route',
              onPressed: onEnd,
              height: 44,
            )
          else if (plan != null)
            PrimaryButton(
              label: plan!.status == RoutePlanStatus.active
                  ? 'Resume route'
                  : 'Activate route',
              loading: busy,
              onPressed: onActivate,
              height: 44,
            )
          else
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: busy ? null : onActivate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.forest),
                      )
                    : const Text('Start ad-hoc route'),
              ),
            ),
        ],
      ),
    );
  }

  String _runningFor(DateTime startedAt) {
    final duration = DateTime.now().difference(startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes}m';
  }
}

class _RouteStopsCard extends StatelessWidget {
  const _RouteStopsCard({required this.plan, this.truck});

  final RoutePlan plan;
  final LatLng? truck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 16, color: AppColors.forest),
              const SizedBox(width: 8),
              const Text(
                'Your route',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                plan.stopsLabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RoutePreviewMap(stops: plan.stops, truck: truck, height: 150),
          if (plan.stops.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Barangay staff did not pin any stops for this run.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (var i = 0; i < plan.stops.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            height: 18,
                            width: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.forest,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              (i + 1).toString(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.stops[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          if (plan.stops[i].hasCoordinates)
                            const Icon(Icons.place_outlined,
                                size: 12, color: AppColors.moss),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreflightSheet extends StatefulWidget {
  const _PreflightSheet({required this.plan});

  final RoutePlan plan;

  @override
  State<_PreflightSheet> createState() => _PreflightSheetState();
}

class _PreflightSheetState extends State<_PreflightSheet> {
  bool _vehicleChecked = false;
  bool _loadChecked = false;
  bool _stayOpen = false;
  bool _refreshing = false;

  Future<void> _refresh(LocationProvider location) async {
    setState(() => _refreshing = true);
    await location.getCurrentLocation();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final accuracy = location.currentPosition?.accuracy;
    final denied = location.error != null;
    // A GPS fix is helpful, not mandatory: a driver may be underground or on
    // a laptop with coarse browser geolocation. The 15s heartbeat fills the
    // position in as soon as the device reports one.
    final hasFix = location.hasLocation;
    final checksDone = _vehicleChecked && _loadChecked && _stayOpen;
    final ready = checksDone;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Pre-flight check',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.plan.zone} · ${widget.plan.windowLabel}',
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasFix
                    ? AppColors.mint.withValues(alpha: 0.6)
                    : AppColors.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasFix ? AppColors.forest : AppColors.sage,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasFix
                        ? Icons.gps_fixed_rounded
                        : denied
                            ? Icons.gps_off_rounded
                            : Icons.gps_not_fixed_rounded,
                    size: 18,
                    color: hasFix ? AppColors.forest : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          denied
                              ? 'Location permission is blocked'
                              : !hasFix
                                  ? 'No GPS fix yet'
                                  : 'GPS ready · ±${accuracy?.round() ?? 0} m',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          denied
                              ? 'You can still start; residents see you once access is granted.'
                              : !hasFix
                                  ? 'You can still start — your position appears once it is available.'
                                  : (accuracy != null && accuracy > 150)
                                      ? 'Coarse fix — the map sharpens as more satellites arrive.'
                                      : 'Residents will see this position once you start.',
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.4,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _refreshing
                        ? null
                        : denied
                            ? () => location.openAppSettings()
                            : () => _refresh(location),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                    child: Text(denied ? 'Settings' : 'Refresh'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _CheckRow(
              value: _vehicleChecked,
              label: 'Vehicle, fuel and collection bins checked',
              onChanged: (v) => setState(() => _vehicleChecked = v),
            ),
            _CheckRow(
              value: _loadChecked,
              label: 'Safety gear on and load area clear',
              onChanged: (v) => setState(() => _loadChecked = v),
            ),
            _CheckRow(
              value: _stayOpen,
              label: 'I will keep the app open while the route runs',
              onChanged: (v) => setState(() => _stayOpen = v),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Activate route',
              onPressed: ready ? () => Navigator.of(context).pop(true) : null,
              height: 46,
            ),
            const SizedBox(height: 6),
            Text(
              !checksDone
                  ? 'Tick the three checks to enable activation.'
                  : denied || !hasFix
                      ? 'Activation works without a fix — location reports once available.'
                      : 'Activation publishes your position to residents immediately.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.forest,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 11, height: 1.35, color: AppColors.forest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.isLive,
    required this.onBroadcast,
  });

  final LocationProvider location;
  final bool isLive;
  final VoidCallback onBroadcast;

  @override
  Widget build(BuildContext context) {
    final denied = location.error != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 16, color: AppColors.forest),
              const SizedBox(width: 8),
              const Text(
                'Device location',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                denied
                    ? 'Blocked'
                    : location.isTracking
                        ? 'Broadcasting'
                        : 'Idle',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: denied
                      ? AppColors.danger
                      : location.isTracking
                          ? AppColors.moss
                          : AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            denied
                ? 'Location permission is required to run a collection route.'
                : location.hasLocation
                    ? location.locationString
                    : 'Waiting for a GPS fix…',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: denied ? AppColors.danger : AppColors.inkMuted,
            ),
          ),
          if (!denied && location.currentPosition?.accuracy != null) ...[
            const SizedBox(height: 6),
            Text(
              'Accuracy ±${location.currentPosition!.accuracy.round()} m',
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: denied
                  ? () => location.openAppSettings()
                  : isLive
                      ? onBroadcast
                      : null,
              icon: Icon(
                denied ? Icons.settings_rounded : Icons.send_rounded,
                size: 15,
              ),
              label: Text(
                denied
                    ? 'Open app settings'
                    : isLive
                        ? 'Broadcast now'
                        : 'Activate a route to broadcast',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.sage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.22) : AppColors.creamBright,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.sage,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.forest : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.moss),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Keep the app open while your route is running. Your location is '
              'sent every 15 seconds; if the app stops reporting for 5 minutes '
              'residents see “signal lost” instead of an old position.',
              style: TextStyle(
                fontSize: 9.5,
                height: 1.5,
                color: AppColors.forest.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
