import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';
export '../models/user.dart';

enum AuthErrorType { emailNotFound, wrongPassword, emailNotVerified }

class AuthException implements Exception {
  final AuthErrorType type;
  const AuthException(this.type);
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Get current user
  AppUser? get currentUser => _currentUser;

  // Auth state changes stream
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        return null;
      }
      return await _getAppUser(firebaseUser);
    });
  }

  Future<AppUser> _getAppUser(User firebaseUser) async {
    final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    final roleStr = doc.data()?['role'] ?? 'user';
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
  Future<AppUser> signUp({
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
    final appUser = await _getAppUser(credential.user!);
    await _auth.signOut();
    AppLogger.info('Account created; verification email requested');
    return appUser;
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

      if (!credential.user!.emailVerified && appUser.role != UserRole.admin) {
        await _auth.signOut();
        _currentUser = null;
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

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  // Send email verification for currently signed-in user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }
    await user.sendEmailVerification();
    AppLogger.info('Verification email requested');
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

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
    AppLogger.info('Password reset email requested');
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
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

  // Delete user (for admin)
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'admin';
  }
}
