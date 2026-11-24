import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/constants/service_districts.dart';
import '../../driver/models/truck_crew_role.dart';
import '../models/user.dart';

/// What City Hall asked to create.
class ProvisionRequest {
  const ProvisionRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.crewRole = TruckCrewRole.driver,
    this.truckId,
    this.phone,
    this.district,
  });

  final String name;
  final String email;
  final String password;
  final UserRole role;

  /// Only meaningful for [UserRole.driver]: a driver or a guide.
  final TruckCrewRole crewRole;

  /// Only meaningful for [UserRole.driver]: the truck he holds.
  final String? truckId;

  final String? phone;

  /// The district a District Officer covers. An SOS for that district rings
  /// only this account.
  final String? district;
}

/// A staff account as City Hall sees it in the list.
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

/// Creates the logins the barangay cannot create for itself.
///
/// A client SDK sign-up normally replaces whoever is signed in, which would
/// throw City Hall out of the console mid-shift. The account is therefore made
/// on a **secondary** Firebase app: that app holds its own session, so the
/// console stays signed in while the new login is created. The profile is then
/// written from the primary app, so the Firestore rules see City Hall as the
/// author of the write.
class ProvisioningService {
  ProvisioningService._();
  static final ProvisioningService _instance = ProvisioningService._();
  factory ProvisioningService() => _instance;

  static const _secondaryAppName = 'ecoconnect-provisioning';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Every account City Hall (or the barangay desk) is responsible for.
  Stream<List<ProvisionedAccount>> watchAccounts() {
    return _users
        .where(
          'role',
          whereIn: [
            'iswim',
            'driver',
            'admin',
            'cityHall',
            'districtOfficer',
            'auditor',
          ],
        )
        .snapshots()
        .map((snap) {
          final accounts = snap.docs.map((doc) {
            final data = doc.data();
            final email = data['email'] as String? ?? '';
            final name = (data['name'] as String?)?.trim();
            return ProvisionedAccount(
              uid: doc.id,
              name: (name == null || name.isEmpty)
                  ? (email.isEmpty ? 'No name' : email.split('@').first)
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
          }).toList();
          // Newest roles first: the people who sign tickets, then the crews.
          int rank(UserRole role) => switch (role) {
            UserRole.cityHall => 0,
            UserRole.districtOfficer => 1,
            UserRole.iswim => 2,
            UserRole.admin => 3,
            UserRole.auditor => 4,
            UserRole.driver => 5,
            UserRole.user => 6,
          };
          accounts.sort((a, b) {
            final byRole = rank(a.role).compareTo(rank(b.role));
            return byRole != 0 ? byRole : a.name.compareTo(b.name);
          });
          return accounts;
        });
  }

  /// The District Officer accounts City Hall is responsible for.
  Stream<List<ProvisionedAccount>> watchDistrictOfficers() => watchAccounts()
      .map(
        (accounts) => accounts
            .where((account) => account.role == UserRole.districtOfficer)
            .toList(growable: false),
      );

  /// The barangay staff a District Officer can ring.
  ///
  /// Queries only `admin` profiles, which is also what the security rule
  /// allows an officer to read — residents and drivers stay private.
  Stream<List<ProvisionedAccount>> watchBarangayStaff() => _db
      .collection('users')
      .where('role', isEqualTo: 'admin')
      .snapshots()
      .map((snap) {
        final staff = snap.docs.map((doc) {
          final data = doc.data();
          final email = data['email'] as String? ?? '';
          final name = (data['name'] as String?)?.trim();
          return ProvisionedAccount(
            uid: doc.id,
            name: (name == null || name.isEmpty)
                ? (email.isEmpty ? 'Barangay staff' : email.split('@').first)
                : name,
            email: email,
            role: UserRole.admin,
            status: data['accountStatus'] as String? ?? 'active',
            phone: data['phone'] as String?,
            barangay: data['barangay'] as String?,
            district: data['district'] as String?,
            photoUrl: data['photoUrl'] as String?,
          );
        }).toList();
        staff.sort((a, b) {
          final byArea = (a.barangay ?? '').compareTo(b.barangay ?? '');
          return byArea != 0 ? byArea : a.name.compareTo(b.name);
        });
        return staff;
      });

  /// Creates the login and its profile. Returns the new uid.
  ///
  /// The password is returned nowhere: it is shown once on screen for City
  /// Hall to hand over, and Firebase never reveals it again.
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
        if (request.truckId != null && request.truckId!.isNotEmpty)
          'assignedTruckId': request.truckId,
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

    if (request.role == UserRole.driver &&
        request.truckId != null &&
        request.truckId!.isNotEmpty) {
      await _linkTruck(request.truckId!, uid, name);
    }

    return uid;
  }

  /// Stamps the crew onto the truck, so Iswim's ticket form shows the account
  /// instead of "no login account".
  Future<void> _linkTruck(String truckId, String uid, String name) async {
    try {
      await _db.collection('trucks').doc(truckId).set({
        'driverAccountId': uid,
        'driverName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // The account exists and works; the truck link can be redone from the
      // fleet screen, so this is not worth failing the whole provisioning.
      debugPrint('Truck link failed for $truckId: $e');
    }
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
        .map((doc) {
          final data = doc.data();
          final email = data['email'] as String? ?? '';
          final name = (data['name'] as String?)?.trim();
          return ProvisionedAccount(
            uid: doc.id,
            name: (name == null || name.isEmpty)
                ? (email.isEmpty ? 'District Officer' : email.split('@').first)
                : name,
            email: email,
            role: UserRole.districtOfficer,
            status: data['accountStatus'] as String? ?? 'active',
            phone: data['phone'] as String?,
            barangay: data['barangay'] as String?,
            district: data['district'] as String?,
            photoUrl: data['photoUrl'] as String?,
          );
        })
        .toList(growable: false);
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
