import 'package:eco_connect/features/auth/utils/type_only_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = TypeOnlyFormatter();
  const empty = TextEditingValue(text: '');

  test('a typed character is accepted', () {
    final result = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: 'U'),
    );
    expect(result.text, 'U');
  });

  test('a pasted password is refused', () {
    final result = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: 'User123!'),
    );
    expect(result.text, isEmpty);
  });

  test('deleting is always allowed', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: 'User'),
      const TextEditingValue(text: 'Use'),
    );
    expect(result.text, 'Use');
  });

  test('replacing the whole value in one go is refused', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: 'User'),
      const TextEditingValue(text: 'Other123!'),
    );
    expect(result.text, 'User');
  });
}
