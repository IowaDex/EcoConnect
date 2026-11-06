/// Philippine mobile number helpers.
///
/// Local format is 11 digits (`09XXXXXXXXX`); stored format is E.164
/// (`+639XXXXXXXXX`).
class Phone {
  const Phone._();

  /// Strips separators and the country code so the field always holds the
  /// local 11-digit number.
  static String localDigits(String? raw) {
    var digits = (raw ?? '').replaceAll(RegExp('[^0-9]'), '');
    if (digits.startsWith('63') && digits.length > 11) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('9')) {
      digits = '0$digits';
    }
    return digits;
  }

  /// Returns an error message when the number is not a valid PH mobile number.
  static String? validate(String? raw) {
    final digits = localDigits(raw);
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length != 11) return 'Phone number must be 11 digits';
    if (!digits.startsWith('09')) return 'Number must start with 09';
    return null;
  }

  /// Converts a local 11-digit number to `+63` form for storage.
  static String toE164(String raw) {
    final digits = localDigits(raw);
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+63${digits.substring(1)}';
    }
    return '+63$digits';
  }
}
