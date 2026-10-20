import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;
  AuthErrorType? _loginErrorType;
  Map<String, dynamic>? _userData;
  UserRole? _userRole;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthErrorType? get loginErrorType => _loginErrorType;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  Map<String, dynamic>? get userData => _userData;
  UserRole? get userRole => _userRole;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((AppUser? user) {
      if (user != null && !user.emailVerified && user.role != UserRole.admin) {
        // Do not auto-login unverified users
        _currentUser = null;
        _userData = null;
        _userRole = null;
      } else {
        _currentUser = user;
        if (user != null) {
          _userRole = user.role;
          _loadUserData(user.uid);
        } else {
          _userData = null;
          _userRole = null;
        }
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _userData = await _authService.getUserData(uid);
      notifyListeners();
    } catch (e) {
      // Silent catch or major error handling
    }
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
      _userData = null;
      _userRole = null;
    } catch (e) {
      _setError(e.toString());
      AppLogger.error('Logout failed', e);
    }
    _setLoading(false);
  }

  Future<bool> sendVerificationEmail() async {
    if (_currentUser == null) return false;

    _setLoading(true);
    try {
      await _authService.sendEmailVerification();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      AppLogger.error('Verification email request failed', e);
      _setLoading(false);
      return false;
    }
  }

  Future<void> refreshUser() async {
    notifyListeners();
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