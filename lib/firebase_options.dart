import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final env = dotenv.env;
    // The iOS SDK rejects app IDs registered for another platform (e.g. web).
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return FirebaseOptions(
      apiKey: (isIOS ? env['FIREBASE_IOS_API_KEY'] : null) ??
          env['FIREBASE_API_KEY']!,
      appId: isIOS
          ? env['FIREBASE_IOS_APP_ID'] ??
              (throw StateError('Set FIREBASE_IOS_APP_ID in .env for iOS builds'))
          : env['FIREBASE_APP_ID']!,
      messagingSenderId: env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: env['FIREBASE_PROJECT_ID']!,
      authDomain: env['FIREBASE_AUTH_DOMAIN'],
      storageBucket: env['FIREBASE_STORAGE_BUCKET'],
    );
  }
}
