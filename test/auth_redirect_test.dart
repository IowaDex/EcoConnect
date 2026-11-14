import 'package:eco_connect/app.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits on the splash while the session is being restored', () {
    expect(authRedirect(initialized: false, role: null, location: '/splash'), isNull);
    expect(authRedirect(initialized: false, role: null, location: '/login'), '/splash');
  });

  test('a restored session skips the login screen', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/splash'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/splash'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/login'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/forgot-password'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/welcome'), '/user');
  });

  test('no session goes to the landing page and stays on public screens', () {
    expect(authRedirect(initialized: true, role: null, location: '/splash'), '/welcome');
    expect(authRedirect(initialized: true, role: null, location: '/user'), '/login');
    expect(authRedirect(initialized: true, role: null, location: '/welcome'), isNull);
    expect(authRedirect(initialized: true, role: null, location: '/signup'), isNull);
    expect(authRedirect(initialized: true, role: null, location: '/forgot-password'), isNull);
  });

  test('a signed-in user never sees the landing page', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/welcome'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/welcome'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/welcome'), '/admin-dashboard');
  });

  test('logged-in users stay on their own pages', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/user'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/wallet'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/driver'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/routes'), isNull);
  });

  test('dispatch moved from the barangay to Iswim', () {
    // Iswim assigns the runs; the barangay has no dispatch screen at all.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/routes'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/routes'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/routes'), '/user');
  });

  test('the barangay lost routes, incidents and account provisioning', () {
    // Incidents go straight to DSQC / City Hall.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/incidents'), '/admin-dashboard');
    // No live dispatch board either.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/live-routes'), '/admin-dashboard');
    // City Hall alone creates logins.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/accounts'), '/admin-dashboard');
    // The old "Users" desk is gone from the barangay for good.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/admin'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/pending-accounts'), '/admin-dashboard');
    // The fleet register is City Hall / Iswim business, not the barangay's.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/fleet'), '/admin-dashboard');
    // The desks the barangay kept.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/verification'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/staff-requests'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/wave2/pass'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/memos/barangay'), isNull);
    // City Hall keeps all three.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/incidents'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/accounts'), isNull);
  });

  test('a role cannot open another role\'s pages by typing the URL', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/incidents'), '/user');
    // The old barangay user desk is gone, so even the barangay bounces off it.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/admin'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/user'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/verification'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/wallet'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/staff-requests'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/verification'), '/driver');
  });

  test('a crew starts on the truck list and may open the dashboard', () {
    // The dashboard needs a truck, so the fleet list is the landing page.
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/splash'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/driver'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/driver'), isNull);
  });

  test('city hall keeps the fleet and account desks to itself', () {
    // City Hall registers the trucks and provisions every government login.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/accounts'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/fleet'), isNull);
    // Iswim owns the fleet but never creates accounts.
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/fleet'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/accounts'), '/iswim');
    // A crew member can never reach either desk.
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/accounts'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/fleet'), '/driver');
  });
}
