import 'package:eco_connect/features/auth/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('password policy', () {
    test('accepts a password with every required character class', () {
      expect(Validators.validatePasswordStrength('Eco-2026!'), isNull);
      expect(Validators.validatePasswordStrength('Abcdef1#'), isNull);
    });

    test('rejects short passwords', () {
      expect(
        Validators.validatePasswordStrength('Ab1!'),
        'Password must contain at least 8 characters',
      );
    });

    test('rejects a missing uppercase letter', () {
      expect(
        Validators.validatePasswordStrength('abcdef1!'),
        'Password must contain one uppercase letter',
      );
    });

    test('rejects a missing lowercase letter', () {
      expect(
        Validators.validatePasswordStrength('ABCDEF1!'),
        'Password must contain one lowercase letter',
      );
    });

    test('rejects a missing number', () {
      expect(
        Validators.validatePasswordStrength('Abcdefg!'),
        'Password must contain one number',
      );
    });

    test('rejects a missing special character', () {
      expect(
        Validators.validatePasswordStrength('Abcdefg1'),
        'Password must contain one special character',
      );
    });

    test('the live checklist and validation agree', () {
      const password = 'Abcdefg1';
      final checks = Validators.passwordChecks(password);
      expect(checks.map((c) => c.met).toList(),
          [true, true, true, true, false]);
      expect(Validators.validatePasswordStrength(password), isNotNull);
    });

    test('the generated crew password passes the policy', () {
      // Matches ProvisioningService._suggestPassword().
      expect(Validators.validatePasswordStrength('Eco-123456!'), isNull);
    });
  });
}
