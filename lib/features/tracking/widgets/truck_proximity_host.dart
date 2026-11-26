import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/area_match.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/services/driver_broadcast_service.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';

/// Alerts a resident when a collection truck starts on their street, and when
/// it comes near them.
///
/// Everything runs on the resident's own phone. The truck's position and zone
/// are public; the resident's position is compared locally and never uploaded,
/// so no driver, resident or admin can see it. Alerts need the app open and
/// (for proximity) a location fix.
///
/// The start alert is written by the resident's own account, because the crew
/// cannot read the resident directory — the rules keep that list to the desks.
/// The document id is derived from the route session, so reopening the app on
/// the same run never repeats the alert.
class TruckProximityHost extends StatefulWidget {
  const TruckProximityHost({super.key, required this.child});

  final Widget child;

  @override
  State<TruckProximityHost> createState() => _TruckProximityHostState();
}

class _TruckProximityHostState extends State<TruckProximityHost> {
  StreamSubscription<CollectionRoute?>? _sub;
  StreamSubscription<List<CollectionRoute>>? _startSub;
  CollectionRoute? _route;
  String? _residentId;
  String? _residentArea;

  /// Route sessions this resident was already told about, so a heartbeat or a
  /// rebuild does not repeat the start alert. A session is kept here rather
  /// than a single value because two trucks can run at once.
  final Set<String> _announced = {};

  final _notifications = NotificationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    context.watch<LocationProvider>(); // re-check on every new position
    final id = user?.role == UserRole.user ? user!.uid : null;
    _residentArea = user?.subdivision;
    if (id != _residentId) {
      _residentId = id;
      _sub?.cancel();
      _startSub?.cancel();
      _sub = null;
      _startSub = null;
      _route = null;
      _announced.clear();
      if (id != null) {
        // Proximity follows the featured truck; the start alert watches every
        // live run, because the truck for this resident's street may not be
        // the one the map features.
        _sub = RouteService().watchActiveRoute().listen((route) {
          _route = route;
          _check();
        }, onError: (_) {});
        _startSub = RouteService().watchLiveRoutes().listen((routes) {
          for (final route in routes) {
            _announceStart(route);
          }
        }, onError: (_) {});
      }
    }
    _check();
  }

  void _check() {
    final id = _residentId;
    final route = _route;
    if (id == null || route == null || route.isStale) return;
    final lat = route.latitude;
    final lng = route.longitude;
    final location = context.read<LocationProvider>();
    if (lat == null || lng == null || !location.hasLocation) return;

    DriverBroadcastService()
        .alertResident(
          residentId: id,
          driverId: route.driverId,
          driverName: route.driverName,
          truck: LatLng(lat, lng),
          resident: LatLng(location.latitude!, location.longitude!),
        )
        .catchError((_) => false);
  }

  /// Tells this resident that a truck has started on their streets.
  ///
  /// Only a live run whose zone is the resident's own area qualifies. A run
  /// for another village, or a route with no zone, stays silent.
  Future<void> _announceStart(CollectionRoute? route) async {
    final id = _residentId;
    if (id == null || route == null || !route.isLive || route.isStale) return;

    final zone = (route.zone ?? '').trim();
    if (!areaServesResident(_residentArea, [zone])) return;

    final session =
        route.sessionId ??
        '${route.driverId}_${route.startedAt?.millisecondsSinceEpoch ?? 0}';
    if (_announced.contains(session)) return;

    final ok = await _notifications.push(
      userId: id,
      title: 'Collection truck started in your area',
      body:
          '${route.driverName} started the $zone route. Have your waste '
          'ready — you can follow the truck live.',
      type: AppNotificationType.route,
      data: {
        'driverId': route.driverId,
        'kind': 'routeStarted',
        'sessionId': session,
      },
      dedupeKey: 'route_start_$session',
    );
    if (ok) _announced.add(session);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _startSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
