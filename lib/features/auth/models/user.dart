import 'account_type.dart';

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

  /// Avatar. Either an http(s) URL or an inline data:image/...;base64,
  /// string when the picture was uploaded from the device.
  final String? photoUrl;
  final String? houseStreet;
  final String? barangay;
  final String? city;
  final String? province;

  /// 'active' for residents, 'pending' until barangay staff approves
  /// driver / staff accounts.
  final String accountStatus;

  /// Resident vs. government personnel. Government accounts unlock the
  /// special collection request feature once verified.
  final AccountType accountType;

  /// Verification lifecycle for this account.
  final VerificationStatus verificationStatus;

  /// Why a verification was rejected, shown to the account owner.
  final String? rejectionReason;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.role = UserRole.user,
    this.age,
    this.phone,
    this.photoUrl,
    this.houseStreet,
    this.barangay,
    this.city,
    this.province,
    this.accountStatus = 'active',
    this.accountType = AccountType.resident,
    this.verificationStatus = VerificationStatus.unverified,
    this.rejectionReason,
  });

  bool get isPendingApproval => accountStatus == 'pending';

  bool get isGovernment => accountType == AccountType.government;

  /// The single check every government-only feature must use. The Firestore
  /// rules repeat the same check server-side, so hiding the UI is never the
  /// only line of defence.
  bool get isVerifiedGovernment =>
      isGovernment && verificationStatus == VerificationStatus.verified;

  bool get isVerificationPending =>
      verificationStatus == VerificationStatus.pending;

  AppUser copyWith({
    String? displayName,
    bool? emailVerified,
    UserRole? role,
    int? age,
    String? phone,
    String? photoUrl,
    String? houseStreet,
    String? barangay,
    String? city,
    String? province,
    String? accountStatus,
    AccountType? accountType,
    VerificationStatus? verificationStatus,
    String? rejectionReason,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      role: role ?? this.role,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      houseStreet: houseStreet ?? this.houseStreet,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      accountStatus: accountStatus ?? this.accountStatus,
      accountType: accountType ?? this.accountType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

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
    // Street first, province last, the way a Philippine address is written.
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
