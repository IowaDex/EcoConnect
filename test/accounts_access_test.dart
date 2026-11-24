import 'package:eco_connect/app.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:eco_connect/features/auth/services/provisioning_service.dart';
import 'package:eco_connect/features/driver/models/truck_crew_role.dart';
import 'package:flutter_test/flutter_test.dart';

ProvisionedAccount _crew(String name, TruckCrewRole crewRole) =>
    ProvisionedAccount(
      uid: name,
      name: name,
      email: '${name.toLowerCase()}@ecoconnect.ph',
      role: UserRole.driver,
      status: 'active',
      crewRole: crewRole,
    );

ProvisionedAccount _staff(String name, UserRole role) => ProvisionedAccount(
  uid: name,
  name: name,
  email: '${name.toLowerCase()}@ecoconnect.ph',
  role: role,
  status: 'active',
);

/// Two desks provision logins and each owns one kind of person: Iswim the
/// drivers, the barangay the truck guides who ride with them. Neither may
/// touch an Iswim, City Hall or barangay login.
void main() {
  group('/accounts is the crew desk', () {
    test('Iswim and the barangay may open it', () {
      for (final role in [UserRole.iswim, UserRole.admin]) {
        expect(
          authRedirect(initialized: true, role: role, location: '/accounts'),
          isNull,
          reason: '$role provisions crew logins',
        );
      }
    });

    test('nobody else may type their way in', () {
      // Each role lands back on its own home rather than the account list.
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.driver,
          location: '/accounts',
        ),
        '/driver',
      );
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.driver,
          location: '/accounts',
          crewRole: TruckCrewRole.guide,
        ),
        '/driver-trucks',
        reason: 'a guide has no plate, so he starts on the fleet list',
      );
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.cityHall,
          location: '/accounts',
        ),
        '/cityhall',
      );
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.user,
          location: '/accounts',
        ),
        '/user',
      );
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.auditor,
          location: '/accounts',
        ),
        '/audit-log',
      );
    });
  });

  group('what a desk owns', () {
    test('one scope per desk, and none for everybody else', () {
      expect(accountScopeFor(UserRole.iswim), AccountScope.drivers);
      expect(accountScopeFor(UserRole.admin), AccountScope.guides);
      expect(accountScopeFor(UserRole.cityHall), AccountScope.none);
      expect(accountScopeFor(UserRole.auditor), AccountScope.none);
      expect(accountScopeFor(UserRole.driver), AccountScope.none);
      expect(accountScopeFor(UserRole.user), AccountScope.none);
      expect(accountScopeFor(null), AccountScope.none);
    });

    test('Iswim sees the drivers; the barangay sees only the guides', () {
      final driver = _crew('Dan', TruckCrewRole.driver);
      final guide = _crew('Gina', TruckCrewRole.guide);

      expect(AccountScope.drivers.covers(driver), isTrue);
      // A guide rides with someone else's plate — the barangay makes him.
      expect(AccountScope.drivers.covers(guide), isFalse);

      expect(AccountScope.guides.covers(driver), isFalse);
      expect(AccountScope.guides.covers(guide), isTrue);

      expect(AccountScope.none.covers(guide), isFalse);
      expect(AccountScope.none.covers(driver), isFalse);
    });

    test('a driver provisioned before crewRole existed still counts', () {
      // Older profiles have no crewRole at all; they are drivers, not guides.
      const legacy = ProvisionedAccount(
        uid: 'old',
        name: 'Old',
        email: 'old@ecoconnect.ph',
        role: UserRole.driver,
        status: 'active',
      );
      expect(AccountScope.drivers.covers(legacy), isTrue);
      expect(AccountScope.guides.covers(legacy), isFalse);
    });

    test('no desk may manage another desk’s account', () {
      for (final role in [
        UserRole.iswim,
        UserRole.cityHall,
        UserRole.admin,
        UserRole.auditor,
      ]) {
        final account = _staff(role.name, role);
        for (final scope in AccountScope.values) {
          expect(
            scope.covers(account),
            isFalse,
            reason: '$scope must not list a ${role.name} login',
          );
        }
      }
    });

    test('a desk only offers the login it may create', () {
      expect(AccountScope.drivers.kind, TruckCrewRole.driver);
      expect(AccountScope.guides.kind, TruckCrewRole.guide);
      expect(AccountScope.none.kind, isNull);

      expect(AccountScope.drivers.canProvision, isTrue);
      expect(AccountScope.guides.canProvision, isTrue);
      expect(AccountScope.none.canProvision, isFalse);
    });
  });
}
