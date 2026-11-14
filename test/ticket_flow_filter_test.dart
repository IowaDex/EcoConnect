import 'package:eco_connect/features/tickets/models/trip_ticket.dart';
import 'package:eco_connect/features/tickets/widgets/ticket_flow_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ticket flow stages', () {
    test('every status belongs to exactly one stage', () {
      for (final status in TicketStatus.values) {
        final owners = TicketFlowStage.values
            .where((stage) => stage.matches(status))
            .toList();
        expect(owners, hasLength(1), reason: 'status ${status.name}');
      }
    });

    test('stage counts add up to the number of tickets', () {
      final tickets = [
        _ticket('a', TicketStatus.issued),
        _ticket('b', TicketStatus.accepted),
        _ticket('c', TicketStatus.running),
        _ticket('d', TicketStatus.submitted),
        _ticket('e', TicketStatus.barangaySigned),
        _ticket('f', TicketStatus.iswimSigned),
        _ticket('g', TicketStatus.completed),
        _ticket('h', TicketStatus.declined),
        _ticket('i', TicketStatus.missed),
        _ticket('j', TicketStatus.cancelled),
        _ticket('k', TicketStatus.rejected),
        _ticket('l', TicketStatus.revisionRequired),
      ];

      final counts = ticketStageCounts(tickets);

      expect(counts[TicketFlowStage.withDriver], 3);
      expect(counts[TicketFlowStage.onTheRoad], 1);
      expect(counts[TicketFlowStage.barangay], 1);
      expect(counts[TicketFlowStage.iswim], 1);
      expect(counts[TicketFlowStage.cityHall], 1);
      expect(counts[TicketFlowStage.completed], 1);
      expect(counts[TicketFlowStage.notCompleted], 4);
      expect(counts.values.fold(0, (sum, count) => sum + count), tickets.length);
    });

    test('filtering keeps only the tickets in the chosen stage', () {
      final tickets = [
        _ticket('a', TicketStatus.completed),
        _ticket('b', TicketStatus.barangaySigned),
        _ticket('c', TicketStatus.completed),
        _ticket('d', TicketStatus.declined),
      ];

      expect(
        ticketsInStage(tickets, TicketFlowStage.completed).map((t) => t.id),
        ['a', 'c'],
      );
      expect(
        ticketsInStage(tickets, TicketFlowStage.iswim).map((t) => t.id),
        ['b'],
      );
      expect(ticketsInStage(tickets, null), tickets);
    });
  });

  group('ticket flow filter bar', () {
    testWidgets('shows every stage with its count and reports the tap',
        (tester) async {
      TicketFlowStage? selected = TicketFlowStage.completed;
      var changed = 0;

      await tester.pumpWidget(
        _wrap(
          TicketFlowFilterBar(
            selected: selected,
            total: 12,
            counts: const {
              TicketFlowStage.withDriver: 3,
              TicketFlowStage.onTheRoad: 1,
              TicketFlowStage.barangay: 2,
              TicketFlowStage.iswim: 1,
              TicketFlowStage.cityHall: 1,
              TicketFlowStage.completed: 4,
              TicketFlowStage.notCompleted: 0,
            },
            onChanged: (stage) {
              changed++;
              selected = stage;
            },
          ),
        ),
      );

      for (final label in const [
        'All',
        'With driver',
        'On the road',
        'Barangay',
        'Your signature',
        'City Hall',
        'Completed',
        'Not completed',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Completed'));
      expect(selected, TicketFlowStage.completed);

      await tester.tap(find.text('Not completed'));
      expect(selected, TicketFlowStage.notCompleted);

      await tester.tap(find.text('All'));
      expect(selected, isNull);
      expect(changed, 3);
    });

    testWidgets('wraps instead of scrolling sideways on a narrow phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          TicketFlowFilterBar(
            selected: null,
            total: 4,
            counts: const {
              TicketFlowStage.completed: 2,
              TicketFlowStage.withDriver: 1,
              TicketFlowStage.notCompleted: 1,
            },
            onChanged: (_) {},
          ),
        ),
      );

      final scrollables = tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .where((s) => s.axisDirection == AxisDirection.right ||
              s.axisDirection == AxisDirection.left);
      expect(scrollables, isEmpty);
      expect(tester.takeException(), isNull);

      // Eight chips cannot fit on one 320px row, so the bar must be taller
      // than a single pill.
      expect(tester.getSize(find.byType(Wrap)).height, greaterThan(40));
    });

    testWidgets('every chip shares one width and rows line up', (tester) async {
      for (final (screenWidth, rows) in const [
        (360.0, 4),
        (800.0, 2),
      ]) {
        tester.view.physicalSize = Size(screenWidth, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          _wrap(
            TicketFlowFilterBar(
              selected: null,
              total: 12,
              counts: const {
                TicketFlowStage.withDriver: 3,
                TicketFlowStage.onTheRoad: 1,
                TicketFlowStage.barangay: 2,
                TicketFlowStage.iswim: 1,
                TicketFlowStage.cityHall: 1,
                TicketFlowStage.completed: 4,
                TicketFlowStage.notCompleted: 0,
              },
              onChanged: (_) {},
            ),
          ),
        );

        final chips = find.byType(GestureDetector);
        expect(chips, findsNWidgets(8));

        final widths = <double>{};
        final tops = <double>{};
        for (var i = 0; i < 8; i++) {
          widths.add(tester.getSize(chips.at(i)).width);
          tops.add(tester.getTopLeft(chips.at(i)).dy);
        }

        expect(widths, hasLength(1), reason: 'at ${screenWidth}px wide');
        expect(tops, hasLength(rows), reason: 'at ${screenWidth}px wide');
        expect(tester.takeException(), isNull);
      }

      tester.view.reset();
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

TripTicket _ticket(String id, TicketStatus status) {
  return TripTicket(
    id: id,
    code: 'TT-2026-0001',
    wave: 1,
    truckId: 'truck-1',
    plateNumber: 'ABC 1234',
    wheelers: 4,
    driverId: 'driver-1',
    driverName: 'Ramon Dela Cruz',
    route: 'Purok 1 – Purok 4',
    zone: 'Zone 3',
    date: '2026-11-14',
    windowStart: '07:00',
    windowEnd: '09:00',
    notes: '',
    status: status,
    createdBy: 'iswim-1',
  );
}
