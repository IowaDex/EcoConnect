class Validators {
  /// Validate email format
  ///
  /// Deliberately loose: any local part, an `@`, a domain, a dot and a TLD of
  /// two or more letters. Stricter patterns (`.com`-only, 2-3 letter TLDs)
  /// reject addresses Firebase Auth happily accepts, which blocked sign-in
  /// with a correct email and password.
  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$');

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Minimum length enforced on every account-creation surface.
  static const passwordMinLength = 8;

  /// Characters accepted as "special". Deliberately broad so a password
  /// manager's output is never rejected.
  static final RegExp _specialCharacter = RegExp(
    r"""[!@#$%^&*(),.?"':{}|<>_\-+=\[\]\\/;~`]""",
  );

  /// One entry per rule, in the order the UI lists them. The `met` flag
  /// drives the live checklist; the label is the same text used in validation
  /// errors so a user never sees two different wordings.
  static List<({String label, bool met})> passwordChecks(String value) {
    return [
      (
        label: 'At least $passwordMinLength characters',
        met: value.length >= passwordMinLength,
      ),
      (label: 'One uppercase letter', met: value.contains(RegExp(r'[A-Z]'))),
      (label: 'One lowercase letter', met: value.contains(RegExp(r'[a-z]'))),
      (label: 'One number', met: value.contains(RegExp(r'[0-9]'))),
      (label: 'One special character', met: _specialCharacter.hasMatch(value)),
    ];
  }

  /// Validate password strength
  static String? validatePasswordStrength(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    for (final check in passwordChecks(value)) {
      if (!check.met) {
        return 'Password must contain ${check.label.toLowerCase()}';
      }
    }

    return null;
  }

  /// Validate confirm password
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (value.length > 50) {
      return 'Name must be less than 50 characters';
    }

    return null;
  }
}
