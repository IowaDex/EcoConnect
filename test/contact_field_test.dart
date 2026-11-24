import 'package:eco_connect/features/auth/utils/phone.dart';
import 'package:eco_connect/features/auth/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mobile number', () {
    test('accepts an 11-digit number that starts with 09', () {
      expect(Phone.validate('09171234567'), isNull);
      expect(Phone.validate('09 17 123 4567'), isNull);
    });

    test('rejects a number that is not 11 digits', () {
      expect(Phone.validate('0917123456'), 'Phone number must be 11 digits');
      expect(Phone.validate('091712345678'), 'Phone number must be 11 digits');
    });

    test('rejects a number that does not start with 09', () {
      expect(Phone.validate('08171234567'), 'Number must start with 09');
    });

    test('reads a +63 number as the local 11 digits', () {
      expect(Phone.localDigits('+63 917 123 4567'), '09171234567');
      expect(Phone.toE164('09171234567'), '+639171234567');
    });
  });

  group('email', () {
    test('accepts a normal address', () {
      expect(Validators.validateEmail('ramon.ecoconnect@gmail.com'), isNull);
      expect(Validators.validateEmail(' crew@quezoncity.gov.ph '), isNull);
    });

    test('rejects an address without a domain or a dot', () {
      expect(
        Validators.validateEmail('ramon@gmail'),
        'Please enter a valid email address',
      );
      expect(
        Validators.validateEmail('ramon.gmail.com'),
        'Please enter a valid email address',
      );
      expect(
        Validators.validateEmail('ramon @gmail.com'),
        'Please enter a valid email address',
      );
    });

    test('rejects an empty address', () {
      expect(Validators.validateEmail('  '), 'Email is required');
    });
  });
}
