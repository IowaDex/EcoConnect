import 'package:flutter/services.dart';

/// Accepts one typed character at a time and refuses anything that arrives in
/// one chunk — a paste, an autofill or a drag-and-drop. Deleting is always
/// allowed, so the field can still be corrected.
///
/// Used by the sign-up confirmation field: the resident has to type the
/// password a second time instead of pasting the first one back in.
class TypeOnlyFormatter extends TextInputFormatter {
  const TypeOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final inserted = newValue.text.length - oldValue.text.length;
    if (inserted > 1) return oldValue;
    return newValue;
  }
}
