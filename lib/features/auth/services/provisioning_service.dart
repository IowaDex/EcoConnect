import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/constants/service_districts.dart';
import '../../driver/models/truck_crew_role.dart';
import '../models/user.dart';

/// A login the desk asked to create.
///
/// Credentials only: the plate is not chosen here. A driver meets his truck in
/// the collection manual Iswim writes, which is the assignment record.
class ProvisionRequest {
  const ProvisionRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.crewRole = TruckCrewRole.driver,
    this.phone,
    this.district,
  });

  final String name;
  final String email;
  final String password;
  final UserRole role;

  /// Only meaningful for [UserRole.driver]: a driver or a guide.
  final TruckCrewRole crewRole;

  final String? phone;

  /// The district a District Officer covers. An SOS for that district rings
  /// only this account.
  final String? district;
}

/// A staff account as the desk sees it in the list.
class ProvisionedAccount {
  const ProvisionedAccount({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.crewRole,
    this.truckId,
    this.phone,
    this.barangay,
    this.district,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String status;
  final TruckCrewRole? crewRole;
  final String? truckId;
  final String? phone;

  /// The barangay a staff account belongs to. Shown in the District Officer's
  /// directory so the right desk is called for the right area.
  final String? barangay;

  /// The legislative district this account covers.
  final String? district;
  final String? photoUrl;

  bool get isActive => status == 'active';
}

/// What an account desk is allowed to see and change.
///
/// Two desks provision logins and neither may touch the other's people:
/// Iswim owns the drivers, the barangay owns its truck guides. City Hall is
/// the only one that sees every role, and no desk may manage an Iswim,
/// City Hall or barangay login.
enum AccountScope {
  /// Iswim: the drivers who hold a plate. Not the guides.
  drivers,

  /// The barangay: its truck guides, and nothing else.
  guides,

  /// Not a desk that provisions logins.
  none,
}

AccountScope accountScopeFor(UserRole? role) => switch (role) {
  UserRole.iswim => AccountScope.drivers,
  UserRole.admin => AccountScope.guides,
  _ => AccountScope.none,
};

extension AccountScopeX on AccountScope {
  bool get canProvision => this != AccountScope.none;

  /// Whether this account belongs on the desk. A guide is a `driver` profile
  /// with `crewRole: guide`, so the role alone cannot tell the two apart. A
  /// driver provisioned before `crewRole` existed counts as a driver.
  bool covers(ProvisionedAccount account) {
    if (account.role != UserRole.driver) return false;
    final isGuide = account.crewRole == TruckCrewRole.guide;
    return switch (this) {
      AccountScope.drivers => !isGuide,
      AccountScope.guides => isGuide,
      AccountScope.none => false,
    };
  }

  /// The one kind of crew login the desk may create.
  TruckCrewRole? get kind => switch (this) {
    AccountScope.drivers => TruckCrewRole.driver,
    AccountScope.guides => TruckCrewRole.guide,
    AccountScope.none => null,
  };
}

/// Creates the crew logins no resident can sign up for.
///
/// A client SDK sign-up normally replaces whoever is signed in, which would
/// throw the desk out of the console mid-shift. The account is therefore made
/// on a **secondary** Firebase app: that app holds its own session, so the
/// console stays signed in while the new login is created. The profile is then
/// written from the primary app, so the Firestore rules see the desk as the
/// author of the write.
class ProvisioningService {
  ProvisioningService._();
  static final ProvisioningService _instance = ProvisioningService._();
  factory ProvisioningService() => _instance;

  static const _secondaryAppName = 'ecoconnect-provisioning';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// The crew accounts this desk is responsible for.
  ///
  /// Scoped at the query, not only on screen: the barangay must not receive
  /// an Iswim or City Hall profile over the wire at all, and the rules would
  /// refuse a write to one anyway.
  Stream<List<ProvisionedAccount>> watchAccounts(AccountScope scope) {
    if (!scope.canProvision) return Stream.value(const <ProvisionedAccount>[]);
    return _users
        .where('role', isEqualTo: UserRole.driver.name)
        .snapshots()
        .map((snap) {
          final accounts = snap.docs
              .map((doc) => _accountFrom(doc))
              .where(scope.covers)
              .toList();
          // Drivers before the guides who ride with them, then by name.
          accounts.sort((a, b) {
            final byRole = (a.crewRole == TruckCrewRole.guide ? 1 : 0)
                .compareTo(b.crewRole == TruckCrewRole.guide ? 1 : 0);
            return byRole != 0 ? byRole : a.name.compareTo(b.name);
          });
          return accounts;
        });
  }

  /// The District Officer accounts City Hall is responsible for.
  ///
  /// Its own query, not [watchAccounts]: that one is scoped to the crew a desk
  /// owns, and City Hall is the only desk that manages officers.
  Stream<List<ProvisionedAccount>> watchDistrictOfficers() => _users
      .where('role', isEqualTo: UserRole.districtOfficer.name)
      .snapshots()
      .map((snap) {
        final officers = snap.docs
            .map((doc) => _accountFrom(doc, fallbackName: 'District Officer'))
            .toList();
        officers.sort((a, b) {
          final byArea = (a.district ?? '').compareTo(b.district ?? '');
          return byArea != 0 ? byArea : a.name.compareTo(b.name);
        });
        return officers;
      });

  /// The barangay staff a District Officer can ring.
  ///
  /// Queries only `admin` profiles, which is also what the security rule
  /// allows an officer to read — residents and drivers stay private.
  Stream<List<ProvisionedAccount>> watchBarangayStaff() => _db
      .collection('users')
      .where('role', isEqualTo: 'admin')
      .snapshots()
      .map((snap) {
        final staff = snap.docs
            .map((doc) => _accountFrom(doc, fallbackName: 'Barangay staff'))
            .toList();
        staff.sort((a, b) {
          final byArea = (a.barangay ?? '').compareTo(b.barangay ?? '');
          return byArea != 0 ? byArea : a.name.compareTo(b.name);
        });
        return staff;
      });

  /// Creates the login and its profile. Returns the new uid.
  ///
  /// Credentials only. The plate is assigned later, in the collection manual
  /// Iswim writes — that is the assignment record, and it is what stamps the
  /// driver onto the truck. A brand-new driver therefore holds no truck yet.
  ///
  /// The password is returned nowhere: it is shown once on screen for the desk
  /// to hand over, and Firebase never reveals it again.
  Future<String> create(ProvisionRequest request) async {
    final email = request.email.trim().toLowerCase();
    final name = request.name.trim();

    final secondary = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: secondary);

    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: request.password,
      );
      await credential.user?.updateDisplayName(name);
    } on FirebaseAuthException catch (e) {
      // The secondary session is disposable either way.
      await auth.signOut().catchError((_) {});
      throw ProvisioningException(_message(e));
    }

    final uid = credential.user!.uid;
    // Close the throw-away session before touching Firestore, so nothing can
    // be written as the new user by accident.
    await auth.signOut().catchError((_) {});

    try {
      await _users.doc(uid).set({
        'name': name,
        'email': email,
        'role': request.role.name,
        // Provisioned by the city, not self-registered: already approved and
        // already email-verified by the desk that made it.
        'accountStatus': 'active',
        'emailVerified': true,
        'accountType': 'government',
        'verificationStatus': 'verified',
        'createdAt': FieldValue.serverTimestamp(),
        'provisionedBy': FirebaseAuth.instance.currentUser?.uid,
        if (request.phone != null && request.phone!.trim().isNotEmpty)
          'phone': request.phone!.trim(),
        if (request.district != null && request.district!.trim().isNotEmpty)
          'district': request.district!.trim(),
        if (request.role == UserRole.driver)
          'crewRole': request.crewRole.wireName,
        // A barangay desk belongs to the served barangay; the district makes
        // SOS routing and incident reads work without asking the desk to
        // re-enter its area.
        if (request.role == UserRole.admin) ...{
          'barangay': ServiceArea.barangay,
          'district': ServiceDistricts.defaultDistrict,
        },
      });
    } catch (e) {
      // A login without a profile can never sign in, so it is safe to leave
      // behind — but the desk must know, or the email is burned.
      throw ProvisioningException(
        'The login was created but the profile could not be saved ($e). '
        'Delete $email in the Firebase console before trying again.',
      );
    }

    return uid;
  }

  /// A sign-in / sign-out of this account, used to hand the phone to the crew
  /// with the password already checked.
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on FirebaseAuthException catch (e) {
      throw ProvisioningException(_message(e));
    }
  }

  /// Freezes a login without deleting it: the app refuses any account that is
  /// not active, so a dismissed crew member loses access immediately.
  Future<void> setActive(String uid, bool active) async {
    await _users.doc(uid).update({
      'accountStatus': active ? 'active' : 'suspended',
    });
  }

  /// Assigns (or moves) the district a District Officer covers. Only City Hall
  /// may write this field, and the security rules repeat that check.
  Future<void> setDistrict(String uid, String district) async {
    final value = district.trim();
    if (value.isEmpty) {
      throw const ProvisioningException('Choose a district first.');
    }
    await _users.doc(uid).update({'district': value});
  }

  /// The active District Officers for one district, newest first.
  ///
  /// An SOS is addressed to these accounts by uid instead of the shared desk
  /// channel, so officers in other districts are not rung. The district is
  /// filtered here rather than in the query so no composite index is needed.
  Future<List<ProvisionedAccount>> officersForDistrict(String district) async {
    final value = district.trim();
    if (value.isEmpty) return const [];
    final snap = await _users
        .where('role', isEqualTo: 'districtOfficer')
        .get();
    return snap.docs
        .where((doc) {
          final data = doc.data();
          return (data['district'] as String?)?.trim() == value &&
              (data['accountStatus'] ?? 'active') == 'active';
        })
        .map(
          (doc) => _accountFrom(doc, fallbackName: 'District Officer'),
        )
        .toList(growable: false);
  }

  /// Removes a crew account for good — a driver who resigned or will never
  /// drive again.
  ///
  /// The Firebase login itself cannot be deleted from the app (that needs the
  /// Admin SDK), so the profile goes and a tombstone stops it being recreated.
  /// Login refuses an account with no profile, which leaves the credentials
  /// inert — but the email also stays taken, so a re-hire needs a new address.
  ///
  /// The live route goes first: a stale presence document would keep a truck
  /// on the residents' map after the driver left. The profile goes last, so a
  /// failure halfway leaves the account listed for the desk to retry instead
  /// of losing track of it.
  Future<void> removeAccount(String uid) async {
    await _db.collection('removed_users').doc(uid).set({
      'removedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('routes').doc(uid).delete();
    await _db.collection('sessions').doc(uid).delete();
    await _users.doc(uid).delete();
  }

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_secondaryAppName);
    } catch (_) {
      return Firebase.initializeApp(
        name: _secondaryAppName,
        options: Firebase.app().options,
      );
    }
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
    'email-already-in-use' =>
      'This email already has an account. Use "Reset password" if the '
          'owner lost access.',
    'invalid-email' => 'Invalid email.',
    'weak-password' =>
      'Password is too weak (8+ characters with upper, lower, number and '
          'special character).',
    'operation-not-allowed' =>
      'Email/Password sign-in is not enabled in the Firebase project.',
    _ => 'Could not create the account (${e.code}).',
  };
}

class ProvisioningException implements Exception {
  const ProvisioningException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One `users` profile as the desks read it.
///
/// The crew desk, the barangay directory and the District Officer list all
/// show the same record, so the mapping lives in one place and none of them
/// can drift when a field is added.
ProvisionedAccount _accountFrom(
  DocumentSnapshot<Map<String, dynamic>> doc, {
  String fallbackName = 'No name',
}) {
  final data = doc.data() ?? const <String, dynamic>{};
  final email = data['email'] as String? ?? '';
  final name = (data['name'] as String?)?.trim();
  return ProvisionedAccount(
    uid: doc.id,
    name: (name == null || name.isEmpty)
        ? (email.isEmpty ? fallbackName : email.split('@').first)
        : name,
    email: email,
    role: UserRole.values.firstWhere(
      (role) => role.name == data['role'],
      orElse: () => UserRole.user,
    ),
    status: data['accountStatus'] as String? ?? 'active',
    crewRole: data['crewRole'] == null
        ? null
        : TruckCrewRoleX.fromName(data['crewRole'] as String?),
    truckId: data['assignedTruckId'] as String?,
    phone: data['phone'] as String?,
    barangay: data['barangay'] as String?,
    district: data['district'] as String?,
    photoUrl: data['photoUrl'] as String?,
  );
}
