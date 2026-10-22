import 'package:eco_connect/app.dart';
import 'package:eco_connect/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits on the splash while the session is being restored', () {
    expect(authRedirect(initialized: false, role: null, location: '/splash'), isNull);
    expect(authRedirect(initialized: false, role: null, location: '/login'), '/splash');
  });

  test('a restored session skips the login screen', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/splash'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/login'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/splash'), '/admin-dashboard');
  });

  test('no session goes to login and stays on auth screens', () {
    expect(authRedirect(initialized: true, role: null, location: '/splash'), '/login');
    expect(authRedirect(initialized: true, role: null, location: '/user'), '/login');
    expect(authRedirect(initialized: true, role: null, location: '/signup'), isNull);
  });

  test('logged-in users stay on their own pages', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/user'), isNull);
  });
}
