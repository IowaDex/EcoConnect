import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
export '../models/user.dart';

enum AuthErrorType {
  emailNotFound,
  wrongPassword,
  emailNotVerified,
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
    final data = doc.data() ?? <String, dynamic>{};
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
  Future<AppUser> signUp({
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

    // Send real Firebase email verification
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
    final appUser = await _getAppUser(credential.user!);
    await _auth.signOut();
    return appUser;
  }

  // Login with email and password
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) throw Exception('Login failed');

      final appUser = await _getAppUser(credential.user!);

      if (appUser.isPendingApproval) {
        await _auth.signOut();
        _currentUser = null;
        throw const AuthException(AuthErrorType.accountPending);
      }

      // Residents must verify their email. Drivers and staff are provisioned
      // by the barangay, so staff approval (accountStatus) is the gate instead.
      if (!credential.user!.emailVerified && appUser.role == UserRole.user) {
        await _auth.signOut();
        _currentUser = null;
        throw const AuthException(AuthErrorType.emailNotVerified);
      }

      return appUser;
    } on FirebaseAuthException catch (e) {
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
  }

  // Resend email verification by signing in temporarily
  Future<void> resendVerificationEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Persist profile edits made from the profile sheet.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // Accounts waiting for barangay staff approval
  Future<List<Map<String, dynamic>>> getPendingAccounts() async {
    final snapshot = await _firestore
        .collection('users')
        .where('accountStatus', isEqualTo: 'pending')
        .get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
  }

  // Approve a driver / staff account
  Future<void> approveAccount(String uid) async {
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
