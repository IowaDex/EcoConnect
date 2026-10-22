import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';
export '../models/user.dart';

enum AuthErrorType { emailNotFound, wrongPassword, emailNotVerified, accountRemoved }

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
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first,
      emailVerified: firebaseUser.emailVerified,
      role: UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.user,
      ),
    );
  }

  // Sign up with email and password and role
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
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

      if (!credential.user!.emailVerified && appUser.role != UserRole.admin) {
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

  // Logout; removes the shared location first, while we still have permission.
  // Returns false if that removal failed (e.g. offline); sign-out still happens.
  Future<bool> logout() async {
    var removed = true;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore
            .collection('shared_locations')
            .doc(uid)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        removed = false;
        AppLogger.error('Could not remove shared location on logout', e);
      }
    }
    await _auth.signOut();
    return removed;
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
    await _firestore.collection('users').doc(uid).update({
      'role': role.name,
    });
  }

  // Delete all of a user's data (for admin). The login account itself can only
  // be removed in the Firebase console; login refuses accounts without a profile.
  Future<void> deleteUser(String uid) async {
    // Tombstone first: the rules then refuse to let them re-create a profile.
    await _firestore.collection('removed_users').doc(uid).set({
      'removedAt': FieldValue.serverTimestamp(),
    });
    final profile = _firestore.collection('users').doc(uid);
    while (true) {
      final page = await profile.collection('locations').limit(400).get();
      if (page.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _firestore.collection('shared_locations').doc(uid).delete();
    // Profile last, so a partial failure leaves the user listed for a retry.
    await profile.delete();
  }
}
