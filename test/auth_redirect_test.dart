import 'package:eco_connect/app.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:eco_connect/features/driver/models/truck_crew_role.dart';
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
    // A pending sign-up types its emailed code before it is a session.
    expect(authRedirect(initialized: true, role: null, location: '/verify-email'), isNull);
  });

  test('a signed-in user never sees the landing page', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/welcome'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/welcome'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/welcome'), '/admin-dashboard');
  });

  test('logged-in users stay on their own pages', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/user'), isNull);
    // Residents track the collection truck from their own dashboard.
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/tracking'), isNull);
    // The recycling wallet is gone; an old bookmark lands on the dashboard.
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/wallet'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/driver'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/routes'), isNull);
  });

  test('an unverified resident is limited to truck tracking', () {
    bool allowed(String location) => authRedirect(
      initialized: true,
      role: UserRole.user,
      location: location,
      restrictedResident: true,
    ) == null;

    expect(allowed('/user'), isTrue);
    expect(allowed('/tracking'), isTrue);
    expect(allowed('/verify-identity'), isTrue);
    expect(allowed('/notifications'), isTrue);

    // Everything that needs a verified account bounces back to the dashboard.
    expect(allowed('/waste-upload'), isFalse);
    expect(allowed('/request-collection'), isFalse);
    expect(allowed('/my-requests'), isFalse);
    expect(allowed('/community'), isFalse);
    expect(allowed('/announcements'), isFalse);
    expect(allowed('/events'), isFalse);
    expect(allowed('/ask-ai'), isFalse);
    expect(authRedirect(
      initialized: true,
      role: UserRole.user,
      location: '/waste-upload',
      restrictedResident: true,
    ), '/user');
  });

  test('dispatch moved from the barangay to Iswim', () {
    // Iswim assigns the runs; the barangay has no dispatch screen at all.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/routes'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/routes'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/routes'), '/user');
  });

  test('the barangay lost routes and account provisioning', () {
    // The incident desk is the barangay's: the dashboard links straight to it.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/incidents'), isNull);
    // No live dispatch board either.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/live-routes'), '/admin-dashboard');
    // City Hall alone creates logins.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/accounts'), '/admin-dashboard');
    // The old "Users" desk is gone from the barangay for good.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/admin'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/pending-accounts'), '/admin-dashboard');
    // The fleet register is City Hall / Iswim business, not the barangay's.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/fleet'), '/admin-dashboard');
    // The recycling station and its points wallet are gone.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/dropoff'), '/admin-dashboard');
    // The desks the barangay kept.
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/verification'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/staff-requests'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/wave2/pass'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/memos/barangay'), isNull);
    // City Hall keeps the incidents desk and the fleet.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/incidents'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/fleet'), isNull);
    // Iswim runs the account desk now, not City Hall.
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/accounts'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/accounts'), '/cityhall');
  });

  test('only a resident may open the ID upload screen', () {
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/verify-identity'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/verify-identity'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/verify-identity'), '/admin-dashboard');
    expect(authRedirect(initialized: true, role: null, location: '/verify-identity'), '/login');
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

  test('a guide lands on the fleet list, never on a truck dashboard', () {
    // The guide holds the device but owns no plate, so the list comes first.
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/splash',
      crewRole: TruckCrewRole.guide,
    ), '/driver-trucks');
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/login',
      crewRole: TruckCrewRole.guide,
    ), '/driver-trucks');
    // Typing a forbidden URL still bounces him to the list, not the dashboard.
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/verification',
      crewRole: TruckCrewRole.guide,
    ), '/driver-trucks');
    // Once he taps a plate the dashboard is a normal page he can open.
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/driver',
      crewRole: TruckCrewRole.guide,
    ), isNull);
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/driver-trucks',
      crewRole: TruckCrewRole.guide,
    ), isNull);
    // A driver is unaffected: his plate is already assigned.
    expect(authRedirect(
      initialized: true,
      role: UserRole.driver,
      location: '/splash',
      crewRole: TruckCrewRole.driver,
    ), '/driver');
  });

  test('city hall keeps the fleet; Iswim runs the account desk', () {
    // City Hall registers the trucks and keeps the incidents desk.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/fleet'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/incidents'), isNull);
    // Iswim provisions its own colleagues and the crew logins.
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/fleet'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/accounts'), isNull);
    // The account desk is Iswim's; City Hall and the barangay have no claim.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/accounts'), '/cityhall');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/accounts'), '/admin-dashboard');
    // A crew member can never reach either desk.
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/accounts'), '/driver');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/fleet'), '/driver');
  });

  test('memo and signature screens stay inside the government desks', () {
    // Every desk keeps its own inbox, detail and compose screens.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/memos/cityHall'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/memo/m1'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/memo/m1/edit'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/memos/new'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/memos/iswim'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/memos/new'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/memos/barangay'), isNull);
    // The signature queue is City Hall's, not the other desks'.
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/cityhall/signatures'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.iswim, location: '/cityhall/signatures'), '/iswim');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/cityhall/signatures'), '/admin-dashboard');
    // Residents and drivers never enter the memo channel.
    expect(authRedirect(initialized: true, role: UserRole.user, location: '/memos/cityHall'), '/user');
    expect(authRedirect(initialized: true, role: UserRole.driver, location: '/memo/m1'), '/driver');
  });

  test('auditors are limited to the audit log', () {
    expect(authRedirect(initialized: true, role: UserRole.auditor, location: '/splash'), '/audit-log');
    expect(authRedirect(initialized: true, role: UserRole.auditor, location: '/audit-log'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.auditor, location: '/accounts'), '/audit-log');
    expect(authRedirect(initialized: true, role: UserRole.auditor, location: '/admin-dashboard'), '/audit-log');
    expect(authRedirect(initialized: true, role: UserRole.admin, location: '/audit-log'), isNull);
    expect(authRedirect(initialized: true, role: UserRole.cityHall, location: '/audit-log'), isNull);
  });
}
