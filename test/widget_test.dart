import 'package:flutter_test/flutter_test.dart';

import 'package:eco_connect/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('rejects empty or malformed email', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('not-an-email'), isNotNull);
    });

    test('accepts a valid email', () {
      expect(Validators.validateEmail('aaron@example.com'), isNull);
    });

    test('enforces password strength', () {
      expect(Validators.validatePasswordStrength('short'), isNotNull);
      expect(Validators.validatePasswordStrength('alllowercase1'), isNotNull);
      expect(Validators.validatePasswordStrength('GoodPass1'), isNull);
    });
  });
}
