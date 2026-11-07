import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final env = dotenv.env;
    String? optional(String key) {
      final value = env[key]?.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    // Fail at startup with the key's name instead of a later, vaguer error.
    String required(String key) =>
        optional(key) ?? (throw StateError('Set $key in .env'));

    // The iOS SDK rejects app IDs registered for another platform (e.g. web).
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return FirebaseOptions(
      apiKey: (isIOS ? optional('FIREBASE_IOS_API_KEY') : null) ??
          required('FIREBASE_API_KEY'),
      appId: required(isIOS ? 'FIREBASE_IOS_APP_ID' : 'FIREBASE_APP_ID'),
      messagingSenderId: required('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: required('FIREBASE_PROJECT_ID'),
      authDomain: optional('FIREBASE_AUTH_DOMAIN'),
      storageBucket: optional('FIREBASE_STORAGE_BUCKET'),
    );
  }
}
