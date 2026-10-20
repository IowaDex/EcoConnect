import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/location_provider.dart';
import 'core/database/database_initializer.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize Firebase using values from .env
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  initializeLocalDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: const EcoConnectApp(),
    ),
  );
}
