import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import './firebase_options.dart';
import './core/boot/boot_progress.dart';
import './core/network/network_status.dart';
import './features/auth/providers/auth_provider.dart';
import './features/driver/providers/truck_provider.dart';
import './features/location/providers/location_provider.dart';
import './core/database/database_initializer.dart';
import './app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each step is announced before it runs, so the entry screen can name the
  // work in progress rather than showing a generic spinner.
  BootProgress.report('Loading configuration');
  await dotenv.load(fileName: '.env');

  BootProgress.report('Connecting to Firebase');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Local testing only: flutter run --dart-define=USE_EMULATOR=true
  if (const bool.fromEnvironment('USE_EMULATOR')) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

  BootProgress.report('Opening the local database');
  initializeLocalDatabase();

  // The session restore itself is asynchronous and finishes inside the
  // AuthProvider listener, so the entry screen keeps showing this line until
  // `isInitialized` flips.
  BootProgress.report('Restoring your session');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        // Which garbage truck the crew is on. Chosen on the truck list and
        // remembered on this device.
        ChangeNotifierProvider(create: (_) => TruckProvider()..restore()),
        // Drives the app-wide truck loading screen when the link drops.
        ChangeNotifierProvider(create: (_) => NetworkStatus()..start()),
      ],
      child: const EcoConnectApp(),
    ),
  );
}
