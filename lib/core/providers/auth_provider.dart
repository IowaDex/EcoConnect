import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';

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
      final blocked =
          user != null && !user.emailVerified && user.role != UserRole.admin;
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
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
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