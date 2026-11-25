import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final env = dotenv.env;

    // Every key in .env is FIREBASE_-prefixed (see .env.example and the
    // Dockerfile), so callers pass the bare name and the prefix is added here.
    String? optional(String key) {
      final value = env['FIREBASE_$key']?.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    // Fail at startup with the key's name instead of a later, vaguer error.
    String required(String key) =>
        optional(key) ?? (throw StateError('Set FIREBASE_$key in .env'));

    // Every platform is its own Firebase app, and the SDK rejects an ID that
    // was registered for another one (e.g. the web ID on a phone). A platform
    // may override the shared values; without an override nothing changes.
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    String platform(String key) {
      if (isIOS) return optional('IOS_$key') ?? required(key);
      if (isAndroid) return optional('ANDROID_$key') ?? required(key);
      return required(key);
    }

    return FirebaseOptions(
      apiKey: platform('API_KEY'),
      appId: platform('APP_ID'),
      messagingSenderId: required('MESSAGING_SENDER_ID'),
      projectId: required('PROJECT_ID'),
      authDomain: optional('AUTH_DOMAIN'),
      storageBucket: optional('STORAGE_BUCKET'),
    );
  }
}
