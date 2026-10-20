import 'package:firebase_auth/firebase_auth.dart';

class EmailService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendVerificationEmail(User user) async {
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendWelcomeEmail(User user) async {
    throw UnsupportedError(
      'Custom welcome emails require a server-side email provider.',
    );
  }

  Future<void> sendNotificationEmail({
    required String to,
    required String subject,
    required String message,
    String? userName,
  }) async {
    throw UnsupportedError(
      'Custom notification emails require a server-side email provider.',
    );
  }
}
