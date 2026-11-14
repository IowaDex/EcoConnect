import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/account_type.dart';
import '../../driver/models/truck_crew_role.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import 'session_service.dart';
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
  /// A resident signed up but has not confirmed their email yet. The session
  /// is kept so the confirmation screen can finish it.
  needsEmailVerification,
  /// The barangay rejected the registration; [AuthException.reason] says why.
  accountDeclined,
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
  late final SessionService _sessions =
      SessionService(_currentAuthTime);
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
    final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    final data = doc.data();
    if (data == null) return null;
    final roleStr = data['role'] ?? 'user';
    final rawAge = data['age'];
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first,
      emailVerified: firebaseUser.emailVerified,
      role: UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.user,
      ),
      accountStatus: data['accountStatus'] as String? ?? 'active',
      // Profiles created before the registration decision existed count as
      // accepted, so nobody is asked to re-approve an old account.
      registrationStatus: data['registrationStatus'] as String? ?? 'accepted',
      age: rawAge is num ? rawAge.toInt() : int.tryParse('${rawAge ?? ''}'),
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      houseStreet: data['houseStreet'] as String?,
      barangay: data['barangay'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
      accountType: AccountTypeX.fromName(data['accountType'] as String?),
      verificationStatus:
          VerificationStatusX.fromName(data['verificationStatus'] as String?),
      rejectionReason: data['rejectionReason'] as String?,
      crewRole: TruckCrewRoleX.fromName(data['crewRole'] as String?),
      // Provisioned drivers open straight onto the truck City Hall linked.
      assignedTruckId: data['assignedTruckId'] as String?,
    );
  }

  /// Re-reads the signed-in profile. Used after staff approve a verification
  /// so the new permissions appear without a sign-out.
  Future<AppUser?> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getAppUser(user);
  }

  // Sign up with email and password and role
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    Map<String, dynamic>? profile,
    AccountType accountType = AccountType.resident,
    UploadPayload? verificationDocument,
    TruckCrewRole crewRole = TruckCrewRole.driver,
  }) async {
    // Only residents sign themselves up (crews and staff are provisioned by
    // City Hall), and every resident uploads an ID for the barangay to check.
    // Checked before the login exists, so a missing ID never leaves an
    // orphaned account behind.
    if (role != UserRole.user) {
      throw Exception('Only residents can sign up in the app.');
    }
    if (verificationDocument == null) {
      throw Exception('Please upload your ID to continue.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    final uid = credential.user!.uid;

    // Pending until two things happen: the resident confirms their email
    // (the Firebase link) and the barangay approves their ID. Only then can
    // they sign in.
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role.name,
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
    await ref.update({'emailVerified': true});
    await NotificationService().notifyStaff(
      title: 'New resident registration',
      body: '${name ?? data['name'] ?? 'A resident'} confirmed their email '
          'and is waiting for ID review.',
      type: AppNotificationType.account,
      data: {'uid': uid},
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
        if (!credential.user!.emailVerified) {
          throw const AuthException(AuthErrorType.needsEmailVerification);
        }
        await credential.user!.getIdToken(true);
        await _markEmailConfirmed(appUser.uid, appUser.displayName);
      }

      if (appUser.isPendingApproval) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountPending);
      }

      if (appUser.accountStatus == 'declined') {
        await _auth.signOut();
        throw AuthException(
          AuthErrorType.accountDeclined,
          reason: appUser.rejectionReason,
        );
      }

      // A frozen login keeps its data but loses access: City Hall suspends a
      // crew member instead of deleting the tickets he signed.
      if (appUser.accountStatus == 'suspended') {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountSuspended);
      }

      // Residents must verify their email. Drivers and staff are provisioned
      // by the barangay, so staff approval (accountStatus) is the gate instead.
      if (!credential.user!.emailVerified && appUser.role == UserRole.user) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.emailNotVerified);
      }

      // The newest login owns the account; any other device is signed out.
      try {
        await _sessions.claim(appUser.uid);
      } catch (_) {
        await _auth.signOut();
        rethrow;
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

  // Append-only record of admin actions. Written before the action, so a failed
  // log stops the change instead of leaving it untracked.
  Future<void> _audit(String action, String targetUid) {
    return _firestore.collection('admin_audit').add({
      'action': action,
      'targetUid': targetUid,
      'actorUid': _auth.currentUser?.uid,
      'at': FieldValue.serverTimestamp(),
    });
  }

  // Persist profile edits made from the profile sheet.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Accounts waiting for barangay staff approval
  Future<List<Map<String, dynamic>>> getPendingAccounts() async {
    final snapshot = await _firestore
        .collection('users')
        .where('accountStatus', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
  }

  // Approve a driver / staff account
  Future<void> approveAccount(String uid) async {
    await _audit('approve', uid);
    await _firestore.collection('users').doc(uid).update({
      'accountStatus': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The resident answers the barangay's registration approval.
  ///
  /// Only an `approved` registration can be answered; the rules enforce the
  /// same transition server-side. Accepting keeps the account as-is, declining
  /// records the withdrawal and alerts the barangay desk.
  Future<void> answerRegistration({
    required String uid,
    required bool accepted,
  }) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) throw StateError('This account no longer exists.');
    if (data['registrationStatus'] != 'approved') {
      throw StateError('There is no approval waiting for your answer.');
    }

    await _firestore.collection('users').doc(uid).update({
      'registrationStatus': accepted ? 'accepted' : 'declined',
      'registrationDecidedAt': FieldValue.serverTimestamp(),
    });

    final name = (data['name'] as String?)?.trim();
    await NotificationService().notifyStaff(
      title: accepted
          ? 'Resident accepted registration'
          : 'Resident declined registration',
      body: accepted
          ? '${name ?? 'A resident'} accepted the barangay approval.'
          : '${name ?? 'A resident'} declined the barangay approval. '
              'The registration is withdrawn.',
      type: AppNotificationType.account,
      data: {'uid': uid},
    );
  }

  /// Active driver accounts, used when staff assign a collection request.
  Future<List<Map<String, dynamic>>> getDrivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .where((driver) =>
            (driver['accountStatus'] as String? ?? 'active') == 'active')
        .toList();
  }

  // Get all users (for admin panel)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => {
      'uid': doc.id,
      ...doc.data(),
    }).toList();
  }

  // Update user role (for admin)
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _audit('role:${role.name}', uid);
    await _firestore.collection('users').doc(uid).update({
      'role': role.name,
    });
  }

  // Delete all of a user's data (for admin). The login account itself can only
  // be removed in the Firebase console; login refuses accounts without a profile.
  // [deleteLocationData] removes the user's location data, which the location
  // feature owns; it runs between the tombstone and the profile delete.
  Future<void> deleteUser(
    String uid, {
    required Future<void> Function() deleteLocationData,
  }) async {
    await _audit('delete', uid);
    // Tombstone first: the rules then refuse to let them re-create a profile.
    await _firestore.collection('removed_users').doc(uid).set({
      'removedAt': FieldValue.serverTimestamp(),
    });
    await deleteLocationData();
    // Profile last, so a partial failure leaves the user listed for a retry.
    await _firestore.collection('users').doc(uid).delete();
  }
}
