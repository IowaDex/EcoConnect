import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_route.dart';
import '../models/route_plan.dart';

/// Raised when a driver's route cannot be activated. The [code] lets the UI
/// react without string-matching the message.
class RouteActivationException implements Exception {
  const RouteActivationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Driver collection runs.
///
/// - `routePlans/{planId}` — staff assignment (zone, day, shift window).
/// - `routes/{driverId}` — the driver's live presence for residents.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _routes =>
      _db.collection('routes');
  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection('routePlans');

  /// The single live route residents should see, if any driver is running.
  Stream<CollectionRoute?> watchActiveRoute() {
    return _routes
        .where('status', whereIn: ['inTransit', 'delayed'])
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : CollectionRoute.fromDoc(snap.docs.first.id, snap.docs.first.data()));
  }

  Stream<CollectionRoute?> watchDriverRoute(String driverId) {
    return _routes.doc(driverId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return CollectionRoute.fromDoc(snap.id, data);
    });
  }

  Stream<RoutePlan?> watchPlan(String planId) {
    return _plans.doc(planId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return RoutePlan.fromDoc(snap.id, data);
    });
  }

  /// The assignment the driver should be running today, if staff created one.
  Stream<RoutePlan?> watchTodayPlan(String driverId) {
    final today = routeDateKey(DateTime.now());
    return _plans
        .where('driverId', isEqualTo: driverId)
        .where('date', isEqualTo: today)
        .snapshots()
        .map((snap) {
      final open = snap.docs
          .map((doc) => RoutePlan.fromDoc(doc.id, doc.data()))
          .where((plan) =>
              plan.status == RoutePlanStatus.scheduled ||
              plan.status == RoutePlanStatus.active)
          .toList()
        ..sort((a, b) => a.windowStart.compareTo(b.windowStart));
      return open.isEmpty ? null : open.first;
    });
  }

  /// Everything scheduled for today, for the staff dispatch board.
  Stream<List<RoutePlan>> watchPlansForToday() {
    final today = routeDateKey(DateTime.now());
    return _plans.where('date', isEqualTo: today).snapshots().map((snap) {
      final plans = snap.docs
          .map((doc) => RoutePlan.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byWindow = a.windowStart.compareTo(b.windowStart);
          return byWindow != 0 ? byWindow : a.driverName.compareTo(b.driverName);
        });
      return plans;
    });
  }

  /// Staff (or a driver starting an unassigned run) creates a plan.
  Future<RoutePlan> createPlan({
    required String driverId,
    required String driverName,
    required String zone,
    required DateTime date,
    required String windowStart,
    required String windowEnd,
    List<RouteStop> stops = const [],
    bool adHoc = false,
    String? createdBy,
  }) async {
    final ref = _plans.doc();
    final plan = RoutePlan(
      id: ref.id,
      driverId: driverId,
      driverName: driverName,
      zone: zone,
      date: routeDateKey(date),
      windowStart: windowStart,
      windowEnd: windowEnd,
      stops: stops,
      adHoc: adHoc,
      createdBy: createdBy,
    );
    await ref.set(plan.toMap());
    return plan;
  }

  Future<void> cancelPlan(String planId) async {
    await _plans.doc(planId).update({
      'status': RoutePlanStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Activates [planId] for [driverId] and publishes their live position.
  ///
  /// All guards run inside one transaction so two taps, two devices, or a
  /// cancelled assignment can never start a route twice:
  ///  * the plan must exist, belong to the driver, be scheduled and be today;
  ///  * the driver must not already have a live route;
  ///  * the shift window is enforced unless [overrideWindow] is passed.
  Future<void> activateRoute({
    required String driverId,
    required String driverName,
    String? phone,
    required String planId,
    double? latitude,
    double? longitude,
    bool overrideWindow = false,
  }) async {
    final routeRef = _routes.doc(driverId);
    final planRef = _plans.doc(planId);
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      final planSnap = await tx.get(planRef);
      final routeSnap = await tx.get(routeRef);

      if (!planSnap.exists) {
        throw const RouteActivationException(
          'plan-missing',
          'This assignment was removed by barangay staff.',
        );
      }

      final plan = RoutePlan.fromDoc(planSnap.id, planSnap.data()!);
      if (plan.driverId != driverId) {
        throw const RouteActivationException(
          'not-yours',
          'This route is assigned to another driver.',
        );
      }
      switch (plan.status) {
        case RoutePlanStatus.active:
          // The plan still says "running" but the driver's presence may be
          // gone (app killed, phone died, route cleared by staff). Allow a
          // restart — the live-route check below still blocks double starts.
          break;
        case RoutePlanStatus.completed:
          throw const RouteActivationException(
            'plan-closed',
            'This route was already completed today.',
          );
        case RoutePlanStatus.cancelled:
          throw const RouteActivationException(
            'plan-cancelled',
            'Barangay staff cancelled this assignment.',
          );
        case RoutePlanStatus.scheduled:
          break;
      }
      if (!plan.isToday) {
        throw const RouteActivationException(
          'not-today',
          'This assignment is not for today.',
        );
      }
      if (!overrideWindow && !plan.isOpenAt(now)) {
        throw RouteActivationException(
          'outside-window',
          'Your shift window is ${plan.windowLabel}.',
        );
      }

      final current = routeSnap.data();
      if (current != null) {
        final status = RouteStatusX.fromName(current['status'] as String?);
        final running = status == RouteStatus.inTransit ||
            status == RouteStatus.delayed;
        if (running && !CollectionRoute.isStaleData(current)) {
          throw const RouteActivationException(
            'already-running',
            'You already have a route running. End it before starting another.',
          );
        }
      }

      final sessionId = '${driverId}_${now.millisecondsSinceEpoch}';
      tx.set(
        routeRef,
        {
          'driverName': driverName,
          'phone': phone,
          'zone': plan.zone,
          'status': RouteStatus.inTransit.name,
          'lat': latitude,
          'lng': longitude,
          'etaMinutes': 12,
          'planId': plan.id,
          'sessionId': sessionId,
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      tx.update(planRef, {
        'status': RoutePlanStatus.active.name,
        'sessionId': sessionId,
        'activatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Heartbeat: called every 15s while the route is live.
  Future<void> pushPosition(
      String driverId, double latitude, double longitude) async {
    await _routes.doc(driverId).set({
      'lat': latitude,
      'lng': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setStatus(String driverId, RouteStatus status) async {
    await _routes.doc(driverId).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Closes the run and marks the assignment completed in the same batch.
  Future<void> endRoute(String driverId, {String? planId}) async {
    final batch = _db.batch();
    batch.set(_routes.doc(driverId), {
      'status': RouteStatus.completed.name,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (planId != null) {
      batch.update(_plans.doc(planId), {
        'status': RoutePlanStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
