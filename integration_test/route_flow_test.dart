import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/models/drop_off.dart';
import 'package:eco_connect/core/models/route_plan.dart';
import 'package:eco_connect/core/services/recycling_service.dart';
import 'package:eco_connect/core/services/route_service.dart';
import 'package:eco_connect/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real service layer against the Firestore emulator.
///
/// Start it with:
///   firebase emulators:exec --only firestore --project ecoconnect-ecaf8 \
///     --config test/emulator/firebase.json \
///     "flutter test integration_test/route_flow_test.dart -d windows"
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final driverId = 'it-driver-$stamp';
  final secondDriverId = 'it-driver-b-$stamp';
  final residentId = 'it-resident-$stamp';
  final planIds = <String>[];

  late FirebaseFirestore db;
  late RouteService routes;
  late RecyclingService recycling;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    db = FirebaseFirestore.instance;
    // Everything below goes to the emulator, never to production.
    //
    // An Android emulator runs its own network stack, so 127.0.0.1 is the
    // phone itself; 10.0.2.2 is the magic alias for the host machine. Desktop
    // and web builds talk to the host loopback directly.
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    db.useFirestoreEmulator(host, 8080);
    routes = RouteService();
    recycling = RecyclingService();
  });

  tearDownAll(() async {
    for (final planId in planIds) {
      await db.collection('routePlans').doc(planId).delete();
    }
    for (final uid in [driverId, secondDriverId, residentId]) {
      await db.collection('routes').doc(uid).delete();
      await db.collection('users').doc(uid).delete();
    }
    final ledger = await db
        .collection('dropOffs')
        .where('residentId', isEqualTo: residentId)
        .get();
    for (final doc in ledger.docs) {
      await doc.reference.delete();
    }
  });

  Future<RoutePlan> assignPlan({
    required String driver,
    String zone = 'Barangay Test',
  }) async {
    final plan = await routes.createPlan(
      driverId: driver,
      driverName: 'Integration Driver',
      zone: zone,
      date: DateTime.now(),
      windowStart: '00:00',
      windowEnd: '23:59',
      stops: const [
        RouteStop(name: 'Purok 1', latitude: 14.6001, longitude: 120.9842),
        RouteStop(
            name: 'Public market', latitude: 14.6032, longitude: 120.9880),
      ],
      createdBy: 'it-staff',
    );
    planIds.add(plan.id);
    return plan;
  }

  /// Runs [action] and returns whatever it threw, or null when it succeeded.
  ///
  /// Web builds box Dart exceptions raised inside Firestore transaction
  /// callbacks as a \`NativeError\`, so the runtime type is not preserved on
  /// that target. Asserting on the rejected state keeps the test honest on
  /// every platform instead of matching an exception class.
  Future<Object?> captureError(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (error) {
      return error;
    }
  }

  testWidgets('full route lifecycle: assign -> activate -> heartbeat -> end',
      (tester) async {
    await tester.runAsync(() async {
      final plan = await assignPlan(driver: driverId);
      expect(plan.status, RoutePlanStatus.scheduled);

      final storedPlan = await db.collection('routePlans').doc(plan.id).get();
      expect(storedPlan.data()!['status'], 'scheduled');
      final storedStops = storedPlan.data()!['stops'] as List;
      expect(storedStops.length, 2);
      expect((storedStops.first as Map)['name'], 'Purok 1');
      expect((storedStops.first as Map)['lat'], 14.6001);

      await routes.activateRoute(
        driverId: driverId,
        driverName: 'Integration Driver',
        phone: '+639000000000',
        planId: plan.id,
        latitude: 14.6001,
        longitude: 120.9842,
      );

      final route = await db.collection('routes').doc(driverId).get();
      expect(route.data()!['status'], 'inTransit');
      expect(route.data()!['planId'], plan.id);
      expect(route.data()!['lastSeenAt'], isNotNull);

      final activePlan = await db.collection('routePlans').doc(plan.id).get();
      expect(activePlan.data()!['status'], 'active');
      expect(activePlan.data()!['sessionId'], isNotNull);

      // A second start must be rejected while the route is live.
      final secondStart = await captureError(
        () => routes.activateRoute(
          driverId: driverId,
          driverName: 'Integration Driver',
          planId: plan.id,
          latitude: 14.6001,
          longitude: 120.9842,
        ),
      );
      expect(secondStart, isNotNull,
          reason: 'a live route must reject a second start');

      await routes.pushPosition(driverId, 14.6010, 120.9860);
      final moved = await db.collection('routes').doc(driverId).get();
      expect(moved.data()!['lat'], 14.6010);
      expect(moved.data()!['lng'], 120.9860);

      await routes.endRoute(driverId, planId: plan.id);
      final ended = await db.collection('routes').doc(driverId).get();
      expect(ended.data()!['status'], 'completed');
      final closed = await db.collection('routePlans').doc(plan.id).get();
      expect(closed.data()!['status'], 'completed');
    });
  });

  testWidgets('a driver cannot activate another driver assignment',
      (tester) async {
    await tester.runAsync(() async {
      final plan = await assignPlan(driver: driverId);

      final rejected = await captureError(
        () => routes.activateRoute(
          driverId: secondDriverId,
          driverName: 'Other Driver',
          planId: plan.id,
          latitude: 14.6,
          longitude: 120.9,
        ),
      );
      expect(rejected, isNotNull,
          reason: 'another driver must not be able to take the assignment');

      final untouched = await db.collection('routePlans').doc(plan.id).get();
      expect(untouched.data()!['status'], 'scheduled');

      final strayRoute = await db.collection('routes').doc(secondDriverId).get();
      expect(strayRoute.exists, isFalse,
          reason: 'a rejected activation must not write a route document');
    });
  });

  testWidgets('drop-off credits points atomically and writes a ledger entry',
      (tester) async {
    await tester.runAsync(() async {
      await db.collection('users').doc(residentId).set({
        'name': 'Integration Resident',
        'email': 'it-resident@example.com',
        'role': 'user',
        'accountStatus': 'active',
      });

      final plastic = await recycling.recordDropOff(
        residentId: residentId,
        residentName: 'Integration Resident',
        residentEmail: 'it-resident@example.com',
        staffId: 'it-staff',
        staffName: 'Integration Staff',
        material: RecyclableMaterial.plastic,
        weightKg: 2.5,
      );
      expect(plastic, 25);

      final glass = await recycling.recordDropOff(
        residentId: residentId,
        residentName: 'Integration Resident',
        staffId: 'it-staff',
        staffName: 'Integration Staff',
        material: RecyclableMaterial.glass,
        weightKg: 1,
      );
      expect(glass, 5);

      final user = await db.collection('users').doc(residentId).get();
      expect(user.data()!['points'], 30);

      final ledger = await db
          .collection('dropOffs')
          .where('residentId', isEqualTo: residentId)
          .get();
      expect(ledger.docs.length, 2);
      expect(
        ledger.docs.map((doc) => doc.data()['points']).toList()..sort(),
        [5, 25],
      );
    });
  });

  testWidgets('points are refused for a non-resident account', (tester) async {
    await tester.runAsync(() async {
      await db.collection('users').doc(secondDriverId).set({
        'name': 'Other Driver',
        'role': 'driver',
      });

      final rejected = await captureError(
        () => recycling.recordDropOff(
          residentId: secondDriverId,
          residentName: 'Other Driver',
          staffId: 'it-staff',
          staffName: 'Integration Staff',
          material: RecyclableMaterial.metal,
          weightKg: 1,
        ),
      );
      expect(rejected, isNotNull,
          reason: 'only resident accounts may earn points');

      final user = await db.collection('users').doc(secondDriverId).get();
      expect(user.data()!.containsKey('points'), isFalse);
    });
  });
}
