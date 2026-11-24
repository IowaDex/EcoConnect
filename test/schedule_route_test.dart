import 'package:eco_connect/app.dart';
import 'package:eco_connect/features/auth/models/user.dart';
import 'package:eco_connect/features/manuals/screens/assignment_schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// A schedule card used to push `/tickets/{id}` for every role. Residents have
/// no route to `/tickets`, so the router bounced them back to the dashboard and
/// the card looked broken.
void main() {
  group('tapping a schedule row', () {
    test('a resident never gets a ticket path', () {
      expect(
        scheduleTicketRoute(isResident: true, ticketId: 't1'),
        isNull,
        reason: 'residents read the schedule, not the crew ticket',
      );
      expect(scheduleTicketRoute(isResident: true, ticketId: null), isNull);
    });

    test('the desk still opens the crew ticket', () {
      expect(
        scheduleTicketRoute(isResident: false, ticketId: 't1'),
        '/tickets/t1',
      );
      // No ticket behind the row: fall back to the detail sheet.
      expect(scheduleTicketRoute(isResident: false, ticketId: null), isNull);
    });

    test('the router really does refuse /tickets for a resident', () {
      // The guard the bug walked into. If this ever becomes allowed, the
      // resident branch above can be reconsidered.
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.user,
          location: '/tickets/t1',
        ),
        '/user',
      );
      // The schedule itself stays open, including for an unverified resident.
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.user,
          location: '/schedule',
        ),
        isNull,
      );
      expect(
        authRedirect(
          initialized: true,
          role: UserRole.user,
          location: '/schedule',
          restrictedResident: true,
        ),
        isNull,
      );
    });
  });
}
