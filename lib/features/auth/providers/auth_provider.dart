import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

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

  AppUser? get currentUser => _currentUser;
  /// False until Firebase has restored (or ruled out) the saved session.
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthErrorType? get loginErrorType => _loginErrorType;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

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
    required UserRole role,
    Map<String, dynamic>? profile,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        profile: profile,
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
      await _authService.login(email: email, password: password);
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
  Future<List<Map<String, dynamic>>> getPendingAccounts() =>
      _authService.getPendingAccounts();

  Future<void> approveAccount(String uid) => _authService.approveAccount(uid);

  Future<List<Map<String, dynamic>>> getAllUsers() => _authService.getAllUsers();

  Future<void> updateUserRole(String uid, UserRole role) =>
      _authService.updateUserRole(uid, role);

  /// [deleteLocationData] is supplied by the caller because the location
  /// feature owns that data and auth must not import it.
  Future<void> deleteUser(
    String uid, {
    required Future<void> Function() deleteLocationData,
  }) =>
      _authService.deleteUser(uid, deleteLocationData: deleteLocationData);

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

  Future<void> logout() async {
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