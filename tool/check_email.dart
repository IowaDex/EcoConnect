// Prints a pass/fail line per address; a console tool, not app code.
// ignore_for_file: avoid_print

import 'package:eco_connect/features/auth/utils/validators.dart';

void main() {
  const emails = [
    'iswim.ecoconnect@gmail.com',
    'cityhall.ecoconnect@gmail.com',
    'barangay.ecoconnect@gmail.com',
    'ramon.ecoconnect@gmail.com',
    'guide.ecoconnect@gmail.com',
    '  iswim.ecoconnect@gmail.com  ',
    'not-an-email',
    '',
  ];
  for (final email in emails) {
    final error = Validators.validateEmail(email);
    print('${error == null ? "OK  " : "FAIL"}  "$email"  ${error ?? ""}');
  }
}
