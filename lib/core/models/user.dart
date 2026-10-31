enum UserRole { user, driver, admin }

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  bool emailVerified;
  UserRole role;

  /// Profile details collected on the second signup step.
  final int? age;
  final String? phone;
  final String? houseStreet;
  final String? barangay;
  final String? city;
  final String? province;

  /// 'active' for residents, 'pending' until barangay staff approves
  /// driver / staff accounts.
  final String accountStatus;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.role = UserRole.user,
    this.age,
    this.phone,
    this.houseStreet,
    this.barangay,
    this.city,
    this.province,
    this.accountStatus = 'active',
  });

  bool get isPendingApproval => accountStatus == 'pending';

  /// First name used for the "Welcome, ..." greeting.
  String get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      final fromEmail = email?.split('@').first;
      if (fromEmail == null || fromEmail.isEmpty) return 'there';
      return fromEmail;
    }
    return name.split(' ').first;
  }

  String get fullAddress {
    final parts = [houseStreet, barangay, city, province]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>();
    return parts.isEmpty ? 'No address on file' : parts.join(', ');
  }

  Map<String, dynamic> toProfileMap() => {
        if (age != null) 'age': age,
        if (phone != null) 'phone': phone,
        if (houseStreet != null) 'houseStreet': houseStreet,
        if (barangay != null) 'barangay': barangay,
        if (city != null) 'city': city,
        if (province != null) 'province': province,
      };
}
