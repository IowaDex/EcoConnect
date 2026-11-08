import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';

/// Publishes the driver's position for as long as a run is live, on every
/// screen and with the app in the background. It follows the driver's route
/// document: GPS (with a background service) starts when the run goes live and
/// stops on pause or end, so nothing is tracked outside a run.
class RunBroadcastHost extends StatefulWidget {
  const RunBroadcastHost({super.key, required this.child});

  final Widget child;

  @override
  State<RunBroadcastHost> createState() => _RunBroadcastHostState();
}

class _RunBroadcastHostState extends State<RunBroadcastHost> {
  static const _interval = Duration(seconds: 15);

  StreamSubscription<CollectionRoute?>? _sub;
  Timer? _timer;
  String? _driverId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final id = user?.role == UserRole.driver ? user!.uid : null;
    if (id == _driverId) return;

    _endRun();
    _sub?.cancel();
    _sub = null;
    _driverId = id;
    if (id != null) {
      _sub = RouteService()
          .watchDriverRoute(id)
          .listen(_onRoute, onError: (_) {});
    }
  }

  void _onRoute(CollectionRoute? route) {
    final live = route?.status == RouteStatus.inTransit ||
        route?.status == RouteStatus.delayed;
    if (!live) {
      _endRun();
      return;
    }
    if (_timer != null) return;
    context.read<LocationProvider>().startTracking(background: true);
    _timer = Timer.periodic(_interval, (_) => _beat());
    _beat();
  }

  void _endRun() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    context.read<LocationProvider>().stopTracking();
  }

  Future<void> _beat() async {
    final id = _driverId;
    if (id == null || !mounted) return;
    final location = context.read<LocationProvider>();
    await location.refreshLocationHealth();
    // With GPS off the provider still holds the last fix; pushing it would make
    // a stale position look fresh. A connectivity blip is different: the fix is
    // live and Firestore queues the write.
    if (!mounted ||
        !location.hasLocation ||
        (location.hasLocationIssue && location.issue != LocationIssue.offline)) {
      return;
    }
    RouteService()
        .pushPosition(id, location.latitude!, location.longitude!)
        .catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
