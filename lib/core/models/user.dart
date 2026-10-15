enum UserRole { user, driver, admin }

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  bool emailVerified;
  UserRole role;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.role = UserRole.user,
  });
}
