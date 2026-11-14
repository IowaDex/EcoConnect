import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../../../core/utils/image_payload.dart';

// Screens get these types through the provider, not the service.
export '../models/user.dart';
export '../services/auth_service.dart' show AuthErrorType;
import '../../../core/utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;
  AuthErrorType? _loginErrorType;
  bool _isInitialized = false;
  StreamSubscription<bool>? _sessionSub;
  bool _sessionReplaced = false;

  AppUser? get currentUser => _currentUser;
  /// False until Firebase has restored (or ruled out) the saved session.
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthErrorType? get loginErrorType => _loginErrorType;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  /// True once another device has signed in to this account. The app shows a
  /// notice and waits for the user to continue before signing out.
  bool get sessionReplaced => _sessionReplaced;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((AppUser? user) {
      // Do not auto-login unverified users
      final blocked = user != null &&
          (user.isPendingApproval ||
              (!user.emailVerified && user.role == UserRole.user));
      _currentUser = blocked ? null : user;
      _isInitialized = true;
      // A login claims its own session first; login() starts the watch then.
      if (_currentUser != null && !_authService.isClaimingSession) {
        _watchSession(_currentUser!.uid);
      } else if (_currentUser == null) {
        _stopWatchingSession();
      }
      notifyListeners();
    }, onError: (Object e) {
      // e.g. offline with no cached profile: fall back to the login screen.
      AppLogger.error('Could not restore session', e);
      _currentUser = null;
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    Map<String, dynamic>? profile,
    AccountType accountType = AccountType.resident,
    UploadPayload? verificationDocument,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        profile: profile,
        accountType: accountType,
        verificationDocument: verificationDocument,
      );
      return true;
    } catch (e) {
      String message = e.toString();
      if (message.contains(']')) {
        message = message.split(']').last.trim();
      } else if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      _setError(message);
      AppLogger.error('Signup failed', e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    _loginErrorType = null;

    try {
      final user =
          await _authService.login(email: email, password: password);
      _watchSession(user.uid);
      return true;
    } on AuthException catch (e) {
      _loginErrorType = e.type;
      switch (e.type) {
        case AuthErrorType.emailNotFound:
          _setError('No account found with this email address.');
        case AuthErrorType.wrongPassword:
          _setError('Invalid email or password. Please try again.');
        case AuthErrorType.emailNotVerified:
          _setError('Please verify your email before logging in.');
        case AuthErrorType.accountPending:
          _setError(
            'Your account is waiting for barangay staff approval. '
            'Please try again once you are approved.',
          );
        case AuthErrorType.accountSuspended:
          _setError(
            'This account is suspended. Ask City Hall to restore your access.',
          );
        case AuthErrorType.accountRejected:
          _setError(
            'Your registration was declined by the barangay. Visit the '
            'barangay hall if you think this is a mistake.',
          );
        case AuthErrorType.accountRemoved:
          _setError('This account has been removed by an administrator.');
      }
      AppLogger.error('Login rejected', e.type);
      return false;
    } catch (e) {
      String message = e.toString();
      if (message.contains(']')) {
        message = message.split(']').last.trim();
      } else if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      _setError(message);
      AppLogger.error('Login request failed', e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Staff-facing account lists, so screens never talk to AuthService directly.
  /// The resident accepts or declines the barangay's registration approval.
  /// Returns an error message, or null on success.
  Future<String?> answerRegistration({required bool accepted}) async {
    final user = _currentUser;
    if (user == null) return 'You are not signed in.';
    try {
      await _authService.answerRegistration(uid: user.uid, accepted: accepted);
      _currentUser =
          user.copyWith(registrationStatus: accepted ? 'accepted' : 'declined');
      notifyListeners();
      return null;
    } catch (e) {
      AppLogger.error('Registration answer failed', e);
      return e is StateError ? e.message : 'Could not save your answer.';
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() => _authService.getAllUsers();

  Future<List<Map<String, dynamic>>> getDrivers() => _authService.getDrivers();

  /// Residents waiting for the barangay's registration decision.
  Future<List<Map<String, dynamic>>> getPendingRegistrations() =>
      _authService.getPendingRegistrations();

  Future<void> updateUserRole(String uid, UserRole role) =>
      _authService.updateUserRole(uid, role);

  /// [deleteLocationData] is supplied by the caller because the location
  /// feature owns that data and auth must not import it.
  Future<void> deleteUser(
    String uid, {
    required Future<void> Function() deleteLocationData,
  }) =>
      _authService.deleteUser(uid, deleteLocationData: deleteLocationData);

  /// Re-reads the profile so verification changes appear without a sign-out.
  Future<void> refreshUser() async {
    try {
      final refreshed = await _authService.refreshProfile();
      if (refreshed != null && refreshed.uid == _currentUser?.uid) {
        _currentUser = refreshed;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Profile refresh failed', e);
    }
  }

  /// Returns an error message to show, or null when the reset email was sent.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'No connection. Check your internet and retry.',
        _ => 'Could not send the reset email. Please try again.',
      };
    } catch (e) {
      AppLogger.error('Password reset request failed', e);
      return 'Could not send the reset email. Please try again.';
    }
  }

  Future<void> resendVerificationEmail(String email, String password) =>
      _authService.resendVerificationEmail(email, password);

  /// Saves profile edits from the profile sheet. Only the fields that were
  /// actually changed are written, so a resident cannot wipe data that another
  /// screen (staff views) still reads.
  Future<bool> updateProfile({
    String? phone,
    String? houseStreet,
    String? photoUrl,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    final data = <String, dynamic>{
      if (phone != null) 'phone': phone,
      if (houseStreet != null) 'houseStreet': houseStreet,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    if (data.isEmpty) return true;

    _setLoading(true);
    try {
      await _authService.updateUserProfile(user.uid, data);
      _currentUser = user.copyWith(
        phone: phone,
        houseStreet: houseStreet,
        photoUrl: photoUrl,
      );
      return true;
    } catch (e) {
      AppLogger.error('Profile update failed', e);
      _setError(e.toString().split(']').last.trim());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _watchSession(String uid) {
    _sessionSub?.cancel();
    _sessionSub = _authService.watchSession(uid).listen((active) {
      if (!active) _onSessionReplaced();
    }, onError: (Object e) => AppLogger.error('Session check failed', e));
  }

  void _stopWatchingSession() {
    _sessionSub?.cancel();
    _sessionSub = null;
  }

  void _onSessionReplaced() {
    _stopWatchingSession();
    if (_currentUser == null) return;
    _sessionReplaced = true;
    notifyListeners();
  }

  /// The user acknowledged the notice: sign out, which sends them to login.
  Future<void> continueAfterSessionReplaced() async {
    _sessionReplaced = false;
    await logout();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  Future<void> logout() async {
    _stopWatchingSession();
    _setLoading(true);
    try {
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      _setError(e.toString());
      AppLogger.error('Logout failed', e);
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    _loginErrorType = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}