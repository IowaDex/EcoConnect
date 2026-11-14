import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String status;
  final TruckCrewRole? crewRole;
  final String? truckId;

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
          whereIn: ['iswim', 'driver', 'admin', 'cityHall', 'auditor'],
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
        );
      }).toList();
      // Newest roles first: the people who sign tickets, then the crews.
      int rank(UserRole role) => switch (role) {
            UserRole.cityHall => 0,
            UserRole.iswim => 1,
            UserRole.admin => 2,
            UserRole.auditor => 3,
            UserRole.driver => 4,
            UserRole.user => 5,
          };
      accounts.sort((a, b) {
        final byRole = rank(a.role).compareTo(rank(b.role));
        return byRole != 0 ? byRole : a.name.compareTo(b.name);
      });
      return accounts;
    });
  }

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
        if (request.role == UserRole.driver) 'crewRole': request.crewRole.wireName,
        if (request.truckId != null && request.truckId!.isNotEmpty)
          'assignedTruckId': request.truckId,
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
        'weak-password' => 'Password is too weak (use at least 6 characters).',
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
