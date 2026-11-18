import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/app.dart';
import 'package:eco_connect/core/database/database_initializer.dart';
import 'package:eco_connect/core/network/network_status.dart';
import 'package:eco_connect/core/widgets/image_picker_field.dart';
import 'package:eco_connect/features/auth/providers/auth_provider.dart';
import 'package:eco_connect/features/auth/services/auth_service.dart';
import 'package:eco_connect/features/driver/providers/truck_provider.dart';
import 'package:eco_connect/features/location/providers/location_provider.dart';
import 'package:eco_connect/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

/// Drives the real app against the Auth and Firestore emulators:
///
///   pending resident signs in -> sees only truck tracking -> uploads an ID
///   -> cannot open the request/waste/complaint screens
///   -> barangay approves -> the dashboard unlocks
///
/// Start the emulators with:
///   firebase emulators:exec --only auth,firestore --project ecoconnect-ecaf8 \
///     --config test/emulator/firebase.unverified.json \
///     "flutter test integration_test/unverified_flow_test.dart -d windows"
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final residentEmail = 'it-pending-$stamp@example.com';
  final unverifiedEmail = 'it-email-$stamp@example.com';
  const password = 'TestPass123!';

  late FirebaseFirestore db;
  String residentUid = '';

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator('127.0.0.1', 8080);
    initializeLocalDatabase();
  });

  tearDownAll(() async {
    await FirebaseAuth.instance.signOut();
    if (residentUid.isNotEmpty) {
      await db.collection('users').doc(residentUid).delete();
      await db.collection('verificationRequests').doc(residentUid).delete();
    }
    await db.collection('routes').doc('it-dan').delete();
  });

  Future<String> verificationCode(String email) async {
    final response = await http.get(
      Uri.parse(
        'http://127.0.0.1:9099/emulator/v1/projects/'
        '${DefaultFirebaseOptions.currentPlatform.projectId}/oobCodes',
      ),
    );
    final codes = (jsonDecode(response.body)['oobCodes'] as List)
        .cast<Map<String, dynamic>>();
    return codes.firstWhere(
          (entry) =>
              entry['email'] == email && entry['requestType'] == 'VERIFY_EMAIL',
        )['oobCode']
        as String;
  }

  /// Creates an account, writes the pending profile, then confirms the email
  /// through the Auth emulator's own out-of-band code.
  ///
  /// [accountStatus] and [verificationStatus] are overridable because an
  /// account can be active and still unverified — the case a resident hit
  /// when the gate looked at `accountStatus` alone.
  Future<String> seedPendingResident({
    required String email,
    required bool verifyEmail,
    String accountStatus = 'pending',
    String? verificationStatus,
    String registrationStatus = 'pending',
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user!;
    final uid = user.uid;

    // The create rule only accepts emailVerified: false, so the profile is
    // born pending and is flipped after the emulator confirms the address.
    await db.collection('users').doc(uid).set({
      'name': 'Pending Resident',
      'email': email,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerified': false,
      'accountStatus': accountStatus,
      'registrationStatus': registrationStatus,
      'accountType': AccountType.resident.name,
      'verificationStatus':
          verificationStatus ?? VerificationStatus.pending.name,
      'barangay': 'Batasan Hills',
      'city': 'Quezon City',
      'province': 'Metro Manila',
      'phone': '+639000000000',
      'houseStreet': 'Block 12, Lot 4',
    });

    await db.collection('verificationRequests').doc(uid).set({
      'userId': uid,
      'name': 'Pending Resident',
      'email': email,
      'phone': '+639000000000',
      'barangay': 'Batasan Hills',
      'accountType': AccountType.resident.name,
      'document': {'dataUrl': 'data:image/png;base64,AAAA'},
      'status': VerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    if (verifyEmail) {
      await user.sendEmailVerification();
      final code = await verificationCode(email);
      await FirebaseAuth.instance.applyActionCode(code);
      await user.reload();
      await user.getIdToken(true);
      await db.collection('users').doc(uid).update({'emailVerified': true});
    }

    await FirebaseAuth.instance.signOut();
    return uid;
  }

  /// Mounts the real app with the providers it expects, then pumps until the
  /// router finishes restoring the session.
  Future<void> pumpResidentApp(
    WidgetTester tester,
    AuthProvider auth, {
    String until = 'ACCOUNT NOT VERIFIED',
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => TruckProvider()..restore()),
          ChangeNotifierProvider(
            create: (_) => NetworkStatus(
              changes: const Stream<Object?>.empty(),
              check: () async => true,
            )..start(),
          ),
        ],
        child: const EcoConnectApp(),
      ),
    );

    // The router starts on the splash until the saved session resolves.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      if (find.textContaining(until).evaluate().isNotEmpty) break;
    }
  }

  testWidgets('unverified resident: tracking only, then unlock on approval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      residentUid = await seedPendingResident(
        email: residentEmail,
        verifyEmail: true,
      );

      // A live run so the tracking card and the map have something to show.
      await db.collection('routes').doc('it-dan').set({
        'status': 'inTransit',
        'driverName': 'Integration Driver',
        'lat': 14.6,
        'lng': 121.0,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
      });

      // The real login gate accepts a pending resident whose email is
      // confirmed, and marks the account restricted.
      final signedIn = await AuthService().login(
        email: residentEmail,
        password: password,
      );
      expect(signedIn.isRestrictedResident, isTrue);
      expect(signedIn.accountStatus, 'pending');
    });

    final auth = AuthProvider();
    await pumpResidentApp(tester, auth);

    // The gate card and the live tracking card are the whole dashboard.
    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsOneWidget);
    expect(find.byType(ImagePickerField), findsOneWidget);
    expect(find.text('The collection truck is on the road'), findsOneWidget);

    // Every write shortcut is present but locked: tapping one names the
    // feature it would have opened, then explains what unlocks it. It never
    // navigates.
    await tester.tap(find.text('Upload waste'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('before you can upload waste photos'),
      findsOneWidget,
    );
    expect(find.text('Submit for validation'), findsNothing);

    // Let the snackbar clear so the next tile's message is unambiguous.
    await tester.pump(const Duration(seconds: 5));

    await tester.ensureVisible(find.text('Complaints'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complaints'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('before you can file a complaint'),
      findsOneWidget,
    );
    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));

    // The Requests tab is locked too.
    await tester.tap(find.text('Requests'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('before you can check your requests'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));

    // Truck tracking is the one open feature.
    await tester.ensureVisible(
      find.text('The collection truck is on the road'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('The collection truck is on the road'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Integration Driver'), findsOneWidget);

    // Back to the dashboard before the approval refresh.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsOneWidget);

    // The barangay desk approves the ID; a refresh unlocks the dashboard.
    await tester.runAsync(() async {
      await db.collection('users').doc(residentUid).update({
        'accountStatus': 'active',
        'registrationStatus': 'accepted',
        'verificationStatus': VerificationStatus.verified.name,
      });
      await auth.refreshUser();
    });
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsNothing);

    // The shortcut now opens the waste upload screen.
    await tester.tap(find.text('Upload waste'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Submit for validation'), findsOneWidget);
  });

  testWidgets('email-unconfirmed resident is still refused at login', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final uid = await seedPendingResident(
        email: unverifiedEmail,
        verifyEmail: false,
      );
      addTearDown(() => db.collection('users').doc(uid).delete());

      await expectLater(
        AuthService().login(email: unverifiedEmail, password: password),
        throwsA(
          isA<AuthException>().having(
            (error) => error.type,
            'type',
            AuthErrorType.needsEmailVerification,
          ),
        ),
      );
      await FirebaseAuth.instance.signOut();
    });
  });

  // Regression: an account can be active and still unverified — an older
  // record, or one approved before the ID check. The gate used to look at
  // accountStatus alone, so these residents kept the full dashboard.
  testWidgets('an active but unverified account is still restricted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final email = 'it-active-$stamp@example.com';
    String uid = '';

    await tester.runAsync(() async {
      uid = await seedPendingResident(
        email: email,
        verifyEmail: true,
        accountStatus: 'active',
        registrationStatus: 'pending',
      );
      final signedIn = await AuthService().login(
        email: email,
        password: password,
      );
      expect(signedIn.accountStatus, 'active');
      expect(signedIn.isRestrictedResident, isTrue);
    });
    addTearDown(() async {
      await FirebaseAuth.instance.signOut();
      if (uid.isEmpty) return;
      await db.collection('users').doc(uid).delete();
      await db.collection('verificationRequests').doc(uid).delete();
    });

    final auth = AuthProvider();
    await pumpResidentApp(tester, auth);

    // Locked exactly like a pending account.
    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsOneWidget);
    expect(find.byType(ImagePickerField), findsOneWidget);

    await tester.ensureVisible(find.text('Complaints'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complaints'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('before you can file a complaint'),
      findsOneWidget,
    );
    expect(find.textContaining('ACCOUNT NOT VERIFIED'), findsOneWidget);
  });
}
