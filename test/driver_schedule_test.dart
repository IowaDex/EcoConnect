import 'package:eco_connect/features/driver/widgets/driver_schedule_card.dart';
import 'package:eco_connect/features/tickets/models/trip_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The calendar under the crew's truck card has to tell a confirmed trip from
/// a manual that is still with City Hall, and name the date of the next trip.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );

  final today = DateTime.now().weekday;

  testWidgets('an approved manual names today as the next trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DriverScheduleCard(
          tickets: [
            _ticket(
              days: [today],
              status: TicketStatus.valid,
              routes: ['Vista Real Executive Village'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Next trip · Today'), findsOneWidget);
    expect(
      find.textContaining('Vista Real Executive Village'),
      findsOneWidget,
    );
  });

  testWidgets('a manual with City Hall is not promised as a trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DriverScheduleCard(
          tickets: [
            _ticket(
              days: [today],
              status: TicketStatus.issued,
              approvalPending: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next trip · waiting for City Hall'), findsOneWidget);
    expect(find.textContaining('Next trip · Today'), findsNothing);
  });

  testWidgets('a crew with no manual is told the calendar fills itself', (
    tester,
  ) async {
    await tester.pumpWidget(host(const DriverScheduleCard(tickets: [])));
    await tester.pumpAndSettle();

    expect(find.text('No trip scheduled yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TripTicket _ticket({
  required List<int> days,
  required TicketStatus status,
  bool approvalPending = false,
  List<String> routes = const ['Northview 2'],
}) {
  return TripTicket(
    id: 't1',
    code: 'TT-2026-0016',
    wave: 1,
    truckId: 'truck-1',
    plateNumber: 'SH 3372',
    wheelers: 4,
    driverId: 'driver-1',
    driverName: 'Paul Domingo',
    route: routes.first,
    zone: 'Zone 3',
    date: '2026-11-24',
    windowStart: '08:00',
    windowEnd: '08:00',
    notes: '',
    status: status,
    createdBy: 'iswim-1',
    kind: TicketKind.assignment,
    routes: routes,
    days: days,
    recurrence: ManualRecurrence.weekly,
    assignmentId: 'manual-1',
    approvalPending: approvalPending,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  );
}
