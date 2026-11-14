import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/collection_route.dart';
import '../models/route_plan.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../collection_points/models/collection_point.dart';
import '../../collection_points/services/collection_point_service.dart';

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
/// - routePlans/{planId} — Iswim's assignment (zone, day, shift window).
/// - routes/{driverId} — the driver's live presence for residents.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  final CollectionPointService _points = CollectionPointService();

  CollectionReference<Map<String, dynamic>> get _routes =>
      _db.collection('routes');
  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection('routePlans');

  /// The single live route residents should see, if any driver is running.
  /// Paused runs stay visible at their last known position so residents are
  /// not left guessing whether the truck is still coming.
  Stream<CollectionRoute?> watchActiveRoute() {
    return watchLiveRoutes().map(pickFeaturedRoute);
  }

  /// Prefers a run that is still reporting over one whose driver went silent
  /// (e.g. an app killed mid-route), then the most recently seen.
  @visibleForTesting
  static CollectionRoute? pickFeaturedRoute(List<CollectionRoute> routes) {
    if (routes.isEmpty) return null;
    final sorted = [...routes]..sort((a, b) {
        if (a.isStale != b.isStale) return a.isStale ? 1 : -1;
        final aSeen = a.lastSeenAt ?? DateTime(2000);
        final bSeen = b.lastSeenAt ?? DateTime(2000);
        return bSeen.compareTo(aSeen);
      });
    return sorted.first;
  }

  /// Every driver currently collecting (including paused runs), for the staff
  /// dispatch map.
  Stream<List<CollectionRoute>> watchLiveRoutes() {
    return _routes
        .where('status', whereIn: ['inTransit', 'delayed', 'paused'])
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollectionRoute.fromDoc(doc.id, doc.data()))
            .whereType<CollectionRoute>()
            .toList());
  }

  Stream<CollectionRoute?> watchDriverRoute(String driverId) {
    return _routes.doc(driverId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return CollectionRoute.fromDoc(snap.id, data);
    });
  }

  /// One assignment, with the driver's collection points merged into its
  /// stops. Residents follow this stream while a run is live, so the tracking
  /// map shows exactly the route the driver sees.
  Stream<RoutePlan?> watchPlan(String planId) {
    late StreamController<RoutePlan?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? planSub;
    StreamSubscription<List<CollectionPoint>>? pointSub;
    RoutePlan? latestPlan;
    var latestPoints = const <CollectionPoint>[];
    String? pointsDriverId;

    void emit() {
      final plan = latestPlan;
      controller.add(plan?.withStops(
        mergeAssignedStops(plan.stops, latestPoints),
      ));
    }

    void watchPoints(String driverId) {
      if (driverId == pointsDriverId) return;
      pointsDriverId = driverId;
      latestPoints = const [];
      pointSub?.cancel();
      pointSub = _points.watchForDriver(driverId).listen(
        (points) {
          latestPoints = points;
          emit();
        },
        onError: (_) {},
      );
    }

    controller = StreamController<RoutePlan?>(
      onListen: () {
        planSub = _plans.doc(planId).snapshots().listen(
          (snap) {
            final data = snap.data();
            latestPlan = data == null ? null : RoutePlan.fromDoc(snap.id, data);
            final plan = latestPlan;
            if (plan != null) watchPoints(plan.driverId);
            emit();
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await planSub?.cancel();
        await pointSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// The assignment the driver should be running today, if staff created one.
  ///
  /// Active collection points assigned to this driver are merged in as stops,
  /// so a location pinned by staff after the plan was created still shows up
  /// on the driver's map. On a name clash the plan's own stop wins.
  Stream<RoutePlan?> watchTodayPlan(String driverId) {
    final today = routeDateKey(DateTime.now());
    final plans = _plans
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
    return _withAssignedStops(plans, _points.watchForDriver(driverId));
  }

  /// Collection points assigned to [driverId] as stops, for ad-hoc runs.
  Future<List<RouteStop>> stopsForDriver(String driverId) async {
    return mergeAssignedStops(const [], await _points.forDriver(driverId));
  }

  /// Turns assigned [points] into stops and appends them after [planStops],
  /// skipping inactive points and names that are already listed.
  static List<RouteStop> mergeAssignedStops(
    List<RouteStop> planStops,
    List<CollectionPoint> points,
  ) {
    final extra = <RouteStop>[
      for (final point in points)
        if (point.isActive)
          RouteStop(
            name: point.name,
            latitude: point.latitude,
            longitude: point.longitude,
            address: _clean(point.address),
            schedule: point.hasSchedule ? point.scheduleLabel : null,
            notes: _clean(point.notes),
          ),
    ];
    return mergeStops(planStops, extra);
  }

  /// Appends stops from [extra] that are not already named in [base]. When a
  /// name appears twice the base stop keeps its position and coordinates, but
  /// picks up any details it was missing.
  static List<RouteStop> mergeStops(
    List<RouteStop> base,
    List<RouteStop> extra,
  ) {
    final merged = <RouteStop>[];
    final indexByName = <String, int>{};
    for (final stop in base) {
      indexByName[stop.name.trim().toLowerCase()] = merged.length;
      merged.add(stop);
    }
    for (final stop in extra) {
      final key = stop.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      final index = indexByName[key];
      if (index == null) {
        indexByName[key] = merged.length;
        merged.add(stop);
      } else {
        merged[index] = _withDetails(merged[index], stop);
      }
    }
    return merged;
  }

  static RouteStop _withDetails(RouteStop base, RouteStop extra) {
    return RouteStop(
      name: base.name,
      latitude: base.latitude ?? extra.latitude,
      longitude: base.longitude ?? extra.longitude,
      address: base.address ?? extra.address,
      schedule: base.schedule ?? extra.schedule,
      notes: base.notes ?? extra.notes,
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Combines plan snapshots with the assigned points stream. Points start as
  /// an empty list and never surface errors, so a slow or denied points read
  /// can never hide the driver's assignment.
  Stream<RoutePlan?> _withAssignedStops(
    Stream<RoutePlan?> plans,
    Stream<List<CollectionPoint>> points,
  ) {
    late StreamController<RoutePlan?> controller;
    StreamSubscription<RoutePlan?>? planSub;
    StreamSubscription<List<CollectionPoint>>? pointSub;
    RoutePlan? latestPlan;
    var latestPoints = const <CollectionPoint>[];
    var hasPlan = false;
    var closed = 0;

    void emit() {
      if (!hasPlan) return;
      final plan = latestPlan;
      controller.add(
        plan?.withStops(mergeAssignedStops(plan.stops, latestPoints)),
      );
    }

    void finish() {
      if (++closed == 2) controller.close();
    }

    controller = StreamController<RoutePlan?>(
      onListen: () {
        planSub = plans.listen(
          (plan) {
            latestPlan = plan;
            hasPlan = true;
            emit();
          },
          onError: controller.addError,
          onDone: finish,
        );
        pointSub = points.listen(
          (value) {
            latestPoints = value;
            emit();
          },
          onError: (_) {},
          onDone: finish,
        );
      },
      onCancel: () async {
        await planSub?.cancel();
        await pointSub?.cancel();
      },
    );
    return controller.stream;
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

  /// A driver's finished runs, newest first, for the Completed tab.
  Stream<List<RoutePlan>> watchCompletedPlans(String driverId) {
    return _plans.where('driverId', isEqualTo: driverId).snapshots().map((snap) {
      final plans = snap.docs
          .map((doc) => RoutePlan.fromDoc(doc.id, doc.data()))
          .where((plan) => plan.status == RoutePlanStatus.completed)
          .toList()
        ..sort((a, b) {
          final aDate = a.completedAt ?? a.createdAt ?? DateTime(2000);
          final bDate = b.completedAt ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return plans;
    });
  }

  /// Iswim (or a driver starting an unassigned run) creates a plan.
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
    String? truckPlate,
    int? truckWheelers,
    String? crewRole,
    double? geofenceLat,
    double? geofenceLng,
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
          'This assignment was removed by Iswim.',
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
            'Iswim cancelled this assignment.',
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
            status == RouteStatus.delayed ||
            status == RouteStatus.paused;
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
          'pausedAt': null,
          'resumedAt': null,
          'completedAt': null,
          'locationState': 'ok',
          'lastKnownLat': latitude,
          'lastKnownLng': longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          // Which vehicle is running, and the point the 100 m radius is
          // measured from. Staff read these on the live routes board.
          if (truckPlate != null) 'truckPlate': truckPlate,
          if (truckWheelers != null) 'truckWheelers': truckWheelers,
          if (crewRole != null) 'crewRole': crewRole,
          'geofenceLat': geofenceLat ?? latitude,
          'geofenceLng': geofenceLng ?? longitude,
          'geofenceRadius': 100,
          'geofenceState': 'ok',
          'connectionState': 'ok',
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

  /// Heartbeat: called every 15s while the route is live. It must not write
  /// `locationState`: the driver screen owns that field and a heartbeat would
  /// overwrite a reported GPS problem with 'ok'.
  Future<void> pushPosition(
      String driverId, double latitude, double longitude) async {
    await _routes.doc(driverId).set({
      'lat': latitude,
      'lng': longitude,
      'lastKnownLat': latitude,
      'lastKnownLng': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
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

  /// Temporarily stops progress tracking while keeping the last position.
  Future<void> pauseRoute({
    required String driverId,
    required String driverName,
    String? zone,
    String? reason,
  }) async {
    await _routes.doc(driverId).set({
      'status': RouteStatus.paused.name,
      'pausedAt': FieldValue.serverTimestamp(),
      'pauseReason': reason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notifications.notifyStaff(
      title: 'Route paused',
      body:
          '$driverName paused the ${zone ?? 'assigned'} route. The last known position is still visible.',
      type: AppNotificationType.route,
      data: {'driverId': driverId},
    );
  }

  /// Restarts a paused run and records the resume timestamp.
  Future<void> resumeRoute({
    required String driverId,
    required String driverName,
    String? zone,
  }) async {
    await _routes.doc(driverId).set({
      'status': RouteStatus.inTransit.name,
      'resumedAt': FieldValue.serverTimestamp(),
      'pausedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notifications.notifyStaff(
      title: 'Route resumed',
      body: '$driverName resumed the ${zone ?? 'assigned'} route.',
      type: AppNotificationType.route,
      data: {'driverId': driverId},
    );
  }

  /// Closes the run and marks the assignment completed in the same batch.
  Future<void> endRoute(
    String driverId, {
    String? planId,
    String? driverName,
    String? zone,
  }) async {
    final batch = _db.batch();
    batch.set(_routes.doc(driverId), {
      'status': RouteStatus.completed.name,
      'endedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'pausedAt': null,
      // The run is over: stop publishing where the truck was.
      'lat': null,
      'lng': null,
      'lastKnownLat': null,
      'lastKnownLng': null,
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

    await _notifications.notifyStaff(
      title: 'Route completed',
      body:
          '${driverName ?? 'A driver'} completed the ${zone ?? 'assigned'} collection route.',
      type: AppNotificationType.route,
      data: {'driverId': driverId, 'planId': planId},
    );
  }
}
