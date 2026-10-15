// Mock Email Service for Windows Testing
// This provides a local implementation without Firebase Cloud Functions
// Replace with real Firebase Cloud Functions when deploying to mobile

class EmailService {
  /// General email sender - mock implementation
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String templateType,
    required Map<String, dynamic> templateData,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    print('📧 [MOCK EMAIL SENT]');
    print('To: $to');
    print('Subject: $subject');
    print('Type: $templateType');
    print('---');
  }

  /// Send verification email for new user sign up
  Future<void> sendVerificationEmail(dynamic user) async {
    await sendEmail(
      to: user.email ?? 'user@example.com',
      subject: 'Verify Your Email - EcoConnect',
      templateType: 'verification',
      templateData: {
        'userName': user.displayName ?? 'User',
        'verificationLink': 'https://ecoconnect.app/verify',
        'appName': 'EcoConnect',
      },
    );
  }

  /// Send welcome email after successful email verification
  Future<void> sendWelcomeEmail(dynamic user) async {
    await sendEmail(
      to: user.email ?? 'user@example.com',
      subject: 'Welcome to EcoConnect!',
      templateType: 'welcome',
      templateData: {
        'userName': user.displayName ?? 'User',
        'appName': 'EcoConnect',
        'loginUrl': 'https://ecoconnect.app/login',
      },
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await sendEmail(
      to: email,
      subject: 'Reset Your Password - EcoConnect',
      templateType: 'passwordReset',
      templateData: {
        'appName': 'EcoConnect',
        'resetLink': 'https://ecoconnect.app/reset-password',
      },
    );
  }

  /// Send notification email (generic)
  Future<void> sendNotificationEmail({
    required String to,
    required String subject,
    required String message,
    String? userName,
  }) async {
    await sendEmail(
      to: to,
      subject: subject,
      templateType: 'notification',
      templateData: {
        'userName': userName ?? 'User',
        'message': message,
        'appName': 'EcoConnect',
      },
    );
  }
}
