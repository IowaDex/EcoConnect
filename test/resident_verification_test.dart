import 'package:eco_connect/features/auth/models/account_type.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resident verification gate', () {
    test('every unverified resident is restricted', () {
      // Waiting for the barangay: the usual case.
      expect(
        AppUser(
          uid: 'u1',
          accountStatus: 'pending',
          verificationStatus: VerificationStatus.pending,
        ).isRestrictedResident,
        isTrue,
      );
      // An active account whose ID was never approved. This is the case that
      // slipped through when the gate looked at accountStatus alone.
      expect(
        AppUser(
          uid: 'u2',
          accountStatus: 'active',
          registrationStatus: 'pending',
          verificationStatus: VerificationStatus.pending,
        ).isRestrictedResident,
        isTrue,
      );
      expect(
        AppUser(
          uid: 'u3',
          accountStatus: 'active',
          verificationStatus: VerificationStatus.unverified,
        ).isRestrictedResident,
        isTrue,
      );
      // A rejected ID must be resubmitted, so it stays locked.
      expect(
        AppUser(
          uid: 'u4',
          accountStatus: 'active',
          verificationStatus: VerificationStatus.rejected,
        ).isRestrictedResident,
        isTrue,
      );
    });

    test('an approved resident keeps every feature', () {
      expect(
        AppUser(
          uid: 'u5',
          accountStatus: 'active',
          registrationStatus: 'accepted',
          verificationStatus: VerificationStatus.verified,
        ).isRestrictedResident,
        isFalse,
      );
    });

    test('crew and staff are never restricted', () {
      // Pending crew are refused at login instead of limited in the app.
      for (final role in [
        UserRole.driver,
        UserRole.admin,
        UserRole.iswim,
        UserRole.cityHall,
        UserRole.auditor,
      ]) {
        expect(
          AppUser(
            uid: role.name,
            role: role,
            accountStatus: 'pending',
            verificationStatus: VerificationStatus.unverified,
          ).isRestrictedResident,
          isFalse,
          reason: '${role.name} should not hit the resident gate',
        );
      }
    });

    test('only a pending account defers the session claim', () {
      // The rules only allow an active account to write sessions/{uid}.
      expect(
        AppUser(uid: 'u6', accountStatus: 'pending').canClaimSession,
        isFalse,
      );
      expect(
        AppUser(uid: 'u7', accountStatus: 'active').canClaimSession,
        isTrue,
      );
      expect(
        AppUser(
          uid: 'u8',
          accountStatus: 'active',
          verificationStatus: VerificationStatus.pending,
        ).canClaimSession,
        isTrue,
      );
    });
  });
}
