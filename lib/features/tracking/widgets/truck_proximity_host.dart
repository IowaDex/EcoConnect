import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../driver/services/driver_broadcast_service.dart';
import '../../location/providers/location_provider.dart';
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';

/// Alerts a resident when the live truck is near them, entirely on their own
/// phone. The truck's position is public; the resident's position is compared
/// locally and never uploaded, so no driver, resident or admin can see it.
/// Alerts need the app open and a location fix (e.g. Real-time tracking on).
class TruckProximityHost extends StatefulWidget {
  const TruckProximityHost({super.key, required this.child});

  final Widget child;

  @override
  State<TruckProximityHost> createState() => _TruckProximityHostState();
}

class _TruckProximityHostState extends State<TruckProximityHost> {
  StreamSubscription<CollectionRoute?>? _sub;
  CollectionRoute? _route;
  String? _residentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    context.watch<LocationProvider>(); // re-check on every new position
    final id = user?.role == UserRole.user ? user!.uid : null;
    if (id != _residentId) {
      _residentId = id;
      _sub?.cancel();
      _sub = null;
      _route = null;
      if (id != null) {
        _sub = RouteService().watchActiveRoute().listen((route) {
          _route = route;
          _check();
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
