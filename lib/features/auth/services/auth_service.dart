import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/account_type.dart';
import '../../driver/models/truck_crew_role.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import 'session_service.dart';
import '../../../core/constants/service_area.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_payload.dart';
export '../models/user.dart';
export '../models/account_type.dart';

enum AuthErrorType {
  emailNotFound,
  wrongPassword,
  emailNotVerified,
  accountRemoved,
  accountPending,
  accountSuspended,

  /// A resident record names a barangay other than the one this deployment
  /// serves.
  outOfArea,

  /// A resident signed up but has not confirmed their email yet. The session
  /// is kept so the confirmation screen can finish it.
  needsEmailVerification,
}

class AuthException implements Exception {
  final AuthErrorType type;
  final String? reason;
  const AuthException(this.type, {this.reason});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final SessionService _sessions = SessionService(_currentAuthTime);
  bool _loggingIn = false;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Auth state changes stream
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      // No sign-out here: during signup the profile is written after this fires.
      return await _getAppUser(firebaseUser);
    });
  }

  /// Returns null when there is no profile: an admin deleted it, or signup
  /// hasn't written it yet.
  Future<AppUser?> _getAppUser(User firebaseUser) async {
    final doc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    final data = doc.data();
    if (data == null) return null;
    final roleStr = data['role'] ?? 'user';
    final rawAge = data['age'];
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      // The desk that provisions a login types the full name, so it wins over
      // whatever display name Firebase kept from signup.
      displayName:
          data['name'] as String? ??
          firebaseUser.displayName ??
          firebaseUser.email?.split('@').first,
      // Either the person clicked the link Firebase mailed, or the desk that
      // provisioned the account marked it verified. Rules stop a resident from
      // setting that flag on their own profile.
      emailVerified:
          firebaseUser.emailVerified || data['emailVerified'] == true,
      role: UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.user,
      ),
      accountStatus: data['accountStatus'] as String? ?? 'active',
      // Profiles created before the registration decision existed count as
      // accepted, so nobody is asked to re-approve an old account.
      registrationStatus: data['registrationStatus'] as String? ?? 'accepted',
      birthdate: _asDate(data['birthdate']),
      age: rawAge is num ? rawAge.toInt() : int.tryParse('${rawAge ?? ''}'),
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      subdivision: data['subdivision'] as String?,
      houseStreet: data['houseStreet'] as String?,
      barangay: data['barangay'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
      accountType: AccountTypeX.fromName(data['accountType'] as String?),
      verificationStatus: VerificationStatusX.fromName(
        data['verificationStatus'] as String?,
      ),
      rejectionReason: data['rejectionReason'] as String?,
      crewRole: TruckCrewRoleX.fromName(data['crewRole'] as String?),
      // Provisioned drivers open straight onto the truck City Hall linked.
      assignedTruckId: data['assignedTruckId'] as String?,
    );
  }

  /// Date of birth is written as an ISO string, but an older profile or a
  /// hand-edited document may hold a Firestore timestamp.
  static DateTime? _asDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Re-reads the signed-in profile. Used after staff approve a verification
  /// so the new permissions appear without a sign-out.
  Future<AppUser?> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getAppUser(user);
  }

  // Resident sign-up. Drivers and guides never register themselves: City Hall
  // provisions those logins, so the role is fixed here.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    Map<String, dynamic>? profile,
    AccountType accountType = AccountType.resident,
    UploadPayload? verificationDocument,
  }) async {
    // Only residents sign themselves up (crews and staff are provisioned by
    // City Hall), and every resident uploads an ID for the barangay to check.
    // Checked before the login exists, so a missing ID never leaves an
    // orphaned account behind.
    if (verificationDocument == null) {
      throw Exception('Please upload your ID to continue.');
    }

    // EcoConnect serves one barangay. Refuse a mismatched profile before the
    // login is created, so no orphaned account is left behind.
    final barangay = (profile?['barangay'] as String?)?.trim() ?? '';
    if (barangay.isNotEmpty && !ServiceArea.covers(barangay)) {
      throw Exception(
        'EcoConnect is only available to residents of ${ServiceArea.barangay}.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    final uid = credential.user!.uid;

    // Pending until the barangay approves the ID. The resident must confirm
    // their email before signing in; until approval the dashboard is limited
    // to tracking the collection truck.
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': UserRole.user.name,
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerified': false,
      'accountStatus': 'pending',
      'registrationStatus': 'pending',
      'accountType': accountType.name,
      'verificationStatus': VerificationStatus.pending.name,
      if (profile != null) ...profile,
    });

    // The ID lives in its own collection so only the owner and barangay staff
    // can read it. Written while the new account is still signed in.
    await _firestore.collection('verificationRequests').doc(uid).set({
      'userId': uid,
      'name': name,
      'email': email,
      'phone': profile?['phone'],
      'barangay': profile?['barangay'],
      'accountType': accountType.name,
      'document': verificationDocument.toMap(),
      'status': VerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    await credential.user?.sendEmailVerification();
    // The session is kept: the confirmation screen needs it next.
    AppLogger.info('Resident signed up; confirmation link sent');
  }

  /// Sends the email confirmation link again.
  Future<void> resendVerificationLink() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Reloads the Firebase user and reports whether the link was clicked.
  /// Does not end the session or write anything.
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Checks whether the resident clicked the link. If so, the profile records
  /// it, the barangay is told a registration is waiting, and the session ends:
  /// the resident signs in once the barangay approves. False if not yet.
  Future<bool> confirmEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    // The rules check the sign-in token, so refresh it to carry the new state.
    await fresh.getIdToken(true);
    await _markEmailConfirmed(fresh.uid, fresh.displayName);
    await _auth.signOut();
    return true;
  }

  /// Records the confirmed email once and tells the barangay the resident is
  /// waiting for ID review.
  Future<void> _markEmailConfirmed(String uid, String? name) async {
    final ref = _firestore.collection('users').doc(uid);
    final data = (await ref.get()).data();
    if (data == null || data['emailVerified'] == true) return;
    // The rules accept this only when the sign-in token says the email is
    // confirmed. Firestore can pick up a just-refreshed token a moment late,
    // so a refusal is retried with a fresh token before giving up.
    for (var attempt = 1; ; attempt++) {
      try {
        await ref.update({'emailVerified': true});
        break;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt >= 4) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
        await _auth.currentUser?.getIdToken(true);
      }
    }
    await NotificationService().notifyStaff(
      title: 'New resident registration',
      body:
          '${name ?? data['name'] ?? 'A resident'} confirmed their email '
          'and is waiting for ID review.',
      type: AppNotificationType.account,
      data: {'uid': uid},
      // The verification screen polls, and a retry must not stack a second
      // "new registration" alert on the barangay desk.
      dedupeKey: 'registration_${uid}_submitted',
    );
  }

  /// The email address of the half-finished sign-up, if one is signed in.
  String? get pendingSignupEmail => _auth.currentUser?.email;

  /// Leaves the email-code step without finishing it.
  Future<void> cancelPendingSignup() => _auth.signOut();

  // Login with email and password
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // The auth listener fires mid-login; it must not watch the session before
    // this device has claimed it.
    _loggingIn = true;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (credential.user == null) throw Exception('Login failed');

      final appUser = await _getAppUser(credential.user!);

      if (appUser == null) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountRemoved);
      }

      // A pending resident: either they still have to confirm their email
      // (the session stays for the confirmation screen), or they clicked the
      // link since signing up and it is recorded now, before the pending
      // message below.
      if (appUser.role == UserRole.user && appUser.isPendingApproval) {
        if (!appUser.emailVerified) {
          throw const AuthException(AuthErrorType.needsEmailVerification);
        }
        await credential.user!.getIdToken(true);
        await _markEmailConfirmed(appUser.uid, appUser.displayName);
      }

      // Crew and staff accounts wait for approval before they may sign in. A
      // resident does not: they sign in with the dashboard locked to truck
      // tracking while the barangay checks their ID.
      if (appUser.isPendingApproval && appUser.role != UserRole.user) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountPending);
      }

      // A rejected ID is not a closed account. The resident signs in to the
      // restricted dashboard and sends a clearer photo from there, so the
      // desk's rejection must never lock them out of their own resubmission.
      // Only a suspension takes the account away.

      // A frozen login keeps its data but loses access: City Hall suspends a
      // crew member instead of deleting the tickets he signed.
      if (appUser.accountStatus == 'suspended') {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountSuspended);
      }

      // One barangay only. A resident record that names another barangay is
      // refused here even if it was created before the restriction existed.
      if (appUser.role == UserRole.user &&
          (appUser.barangay ?? '').trim().isNotEmpty &&
          !ServiceArea.covers(appUser.barangay)) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.outOfArea);
      }

      // Residents confirm their email, but the barangay's ID check is the
      // stronger proof of identity, and the default Firebase mail often never
      // arrives. Once the desk has decided on the ID, that decision stands in
      // for the confirmation: an approval records `emailVerified` too, and a
      // rejection must stay reachable so the resident can resubmit. Only a
      // resident the desk has not looked at yet waits for the email.
      if (!appUser.emailGateCleared) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.emailNotVerified);
      }

      // The newest login owns the account; any other device is signed out.
      // A pending account cannot write the session record yet (the rules only
      // allow active accounts), so it skips this until the barangay approves.
      if (appUser.canClaimSession) {
        try {
          await _sessions.claim(appUser.uid);
        } catch (_) {
          await _auth.signOut();
          rethrow;
        }
      }

      AppLogger.info('Login successful');
      return appUser;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Login failed (${e.code})', e.message);
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        throw const AuthException(AuthErrorType.emailNotFound);
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException(AuthErrorType.wrongPassword);
      }
      rethrow;
    } finally {
      _loggingIn = false;
    }
  }

  // Callers remove any data that needs the signed-in session (e.g. the shared
  // location) before calling this.
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _sessions.forget(uid);
    await _auth.signOut();
  }

  /// When the current login was issued (epoch seconds); the rules compare it
  /// with the session's recorded time.
  Future<int> _currentAuthTime() async {
    final token = await _auth.currentUser?.getIdTokenResult();
    final issued = token?.authTime;
    if (issued == null) throw StateError('No sign-in time on the login token');
    return issued.millisecondsSinceEpoch ~/ 1000;
  }

  bool get isClaimingSession => _loggingIn || _sessions.isClaiming;

  /// Claims the single-device session for an account that was just approved
  /// while signed in. Pending accounts skip the claim at login.
  Future<void> claimSession(String uid) => _sessions.claim(uid);

  /// False once another device signs in to this account.
  Stream<bool> watchSession(String uid) => _sessions.watch(uid);

  // Sends Firebase's password reset email. An unknown address is treated as
  // success so the screen cannot be used to find out who has an account.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      AppLogger.info('Password reset requested');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      AppLogger.error('Password reset failed (${e.code})', e.message);
      rethrow;
    }
  }

  // Resend email verification by signing in temporarily
  Future<void> resendVerificationEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
    await _auth.signOut();
    AppLogger.info('Verification email resent');
  }

  // Persist profile edits made from the profile sheet.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Residents who signed up and are waiting for the barangay's decision.
  // Filtered on the client: two equality filters would need a composite index,
  // and the residents list is small.
  Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .where(
          (u) =>
              (u['role'] ?? 'user') == 'user' &&
              (u['registrationStatus'] ?? 'accepted') == 'pending' &&
              // A rejected application is no longer waiting on the desk; it only
              // comes back if the resident resubmits.
              (u['verificationStatus'] ?? 'unverified') != 'rejected',
        )
        .toList();
  }

  /// Active driver accounts, used when staff assign a collection request.
  Future<List<Map<String, dynamic>>> getDrivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .where(
          (driver) =>
              (driver['accountStatus'] as String? ?? 'active') == 'active',
        )
        .toList();
  }

  // Get all users (for admin panel)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
  }

  /// Live resident directory for the barangay validation desk.
  ///
  /// A stream, not a one-shot read, so an approval, a new sign-up or a
  /// resubmitted ID appears without pulling to refresh.
  Stream<List<Map<String, dynamic>>> watchResidents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'uid': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // Update user role (for admin)
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).update({'role': role.name});
  }

  // Delete all of a user's data (for admin). The login account itself can only
  // be removed in the Firebase console; login refuses accounts without a profile.
  // [deleteLocationData] removes the user's location data, which the location
  // feature owns; it runs between the tombstone and the profile delete.
  Future<void> deleteUser(
    String uid, {
    required Future<void> Function() deleteLocationData,
  }) async {
    // Tombstone first: the rules then refuse to let them re-create a profile.
    await _firestore.collection('removed_users').doc(uid).set({
      'removedAt': FieldValue.serverTimestamp(),
    });
    await deleteLocationData();
    // Profile last, so a partial failure leaves the user listed for a retry.
    await _firestore.collection('users').doc(uid).delete();
  }
}
