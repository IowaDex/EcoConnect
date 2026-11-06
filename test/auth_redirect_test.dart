import 'package:eco_connect/app.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits on the splash while the session is being restored', () {
    expect(authRedirect(initialized: false, role: null, location: '/splash'), isNull);
    expect(authRedirect(initialized: false, role: null, location: '/login'), '/splash');
  });

  test('a restored session skips the login screen', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/splash'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/login'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/forgot-password'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/splash'), isNull);
  });

  test('no session goes to login and stays on auth screens', () {
    expect(authRedirect(initialized: true, role: null, location: '/splash'), isNull);
    expect(authRedirect(initialized: true, role: null, location: '/user'), '/login');
    expect(authRedirect(initialized: true, role: null, location: '/signup'), isNull);
    expect(authRedirect(initialized: true, role: null, location: '/forgot-password'), isNull);
  });

  test('logged-in users stay on their own pages', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/user'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/wallet'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/driver'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/routes'), isNull);
  });

  test('a role cannot open another role\'s pages by typing the URL', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/incidents'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/admin'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/user'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/pending-accounts'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/wallet'), '/admin-dashboard');
  });
}
