import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../../../core/utils/app_logger.dart';
export '../models/user.dart';

enum AuthErrorType {
  emailNotFound,
  wrongPassword,
  emailNotVerified,
  accountRemoved,
  accountPending,
}

class AuthException implements Exception {
  final AuthErrorType type;
  const AuthException(this.type);
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      age: rawAge is num ? rawAge.toInt() : int.tryParse('${rawAge ?? ''}'),
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      houseStreet: data['houseStreet'] as String?,
      barangay: data['barangay'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
    );
  }

  // Sign up with email and password and role
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    Map<String, dynamic>? profile,
  }) async {
    // Create Firebase user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name
    await credential.user?.updateDisplayName(name);

    // Send Firebase Authentication's built-in verification email
    await credential.user?.sendEmailVerification();

    // Store user data in Firestore
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'name': name,
      'email': email,
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerified': false,
      // Drivers and barangay staff need approval before they can sign in.
      'accountStatus': role == UserRole.user ? 'active' : 'pending',
      if (profile != null) ...profile,
    });

    // Do not keep them logged in until email is verified
    await _auth.signOut();
    AppLogger.info('Account created; verification email requested');
  }

  // Login with email and password
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

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

      if (appUser.isPendingApproval) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.accountPending);
      }

      // Residents must verify their email. Drivers and staff are provisioned
      // by the barangay, so staff approval (accountStatus) is the gate instead.
      if (!credential.user!.emailVerified && appUser.role == UserRole.user) {
        await _auth.signOut();
        throw const AuthException(AuthErrorType.emailNotVerified);
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
    }
  }

  // Callers remove any data that needs the signed-in session (e.g. the shared
  // location) before calling this.
  Future<void> logout() => _auth.signOut();

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
