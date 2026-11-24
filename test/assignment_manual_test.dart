import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/constants/resident_areas.dart';
import 'package:eco_connect/core/utils/simple_pdf.dart';
import 'package:eco_connect/features/manuals/data/manual_areas.dart';
import 'package:eco_connect/features/manuals/models/assignment_manual.dart';
import 'package:eco_connect/features/tickets/models/trip_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('manual route limits', () {
    test('a truck takes one area for every two wheels', () {
      expect(maxRoutesForWheelers(4), 2);
      expect(maxRoutesForWheelers(6), 3);
      expect(maxRoutesForWheelers(8), 4);
      expect(maxRoutesForWheelers(10), 5);
    });
  });

  group('driver gap', () {
    test('an HH:mm start becomes minutes since midnight', () {
      expect(manualMinutes('00:00'), 0);
      expect(manualMinutes('08:00'), 480);
      expect(manualMinutes('18:30'), 1110);
    });

    test('shifts need six hours between them', () {
      // 8 AM and 6 PM are two shifts.
      expect(manualSlotsClash('08:00', '18:00'), isFalse);
      // Exactly six hours apart is allowed.
      expect(manualSlotsClash('08:00', '14:00'), isFalse);
      // The same start, or anything closer, is one slot.
      expect(manualSlotsClash('08:00', '08:00'), isTrue);
      expect(manualSlotsClash('08:00', '13:59'), isTrue);
      expect(manualSlotsClash('18:00', '08:00'), isFalse);
    });

    test('a driver is matched by uid, or by name without one', () {
      // Two rows from the accounts list.
      expect(
        manualSameDriver(
          driverId: 'd1',
          driverName: 'Arwin Decena',
          otherDriverId: 'd1',
          otherDriverName: 'Arwin D.',
        ),
        isTrue,
      );
      expect(
        manualSameDriver(
          driverId: 'd1',
          driverName: 'Arwin Decena',
          otherDriverId: 'd2',
          otherDriverName: 'Arwin Decena',
        ),
        isFalse,
      );
      // Roster names carry no uid, so the name decides.
      expect(
        manualSameDriver(
          driverId: '',
          driverName: ' Ben Cruz ',
          otherDriverId: '',
          otherDriverName: 'ben cruz',
        ),
        isTrue,
      );
      expect(
        manualSameDriver(
          driverId: '',
          driverName: 'Ben Cruz',
          otherDriverId: '',
          otherDriverName: 'Ramon Dela Cruz',
        ),
        isFalse,
      );
      // An unnamed row never matches another unnamed row.
      expect(
        manualSameDriver(
          driverId: '',
          driverName: '',
          otherDriverId: '',
          otherDriverName: '',
        ),
        isFalse,
      );
    });
  });

  group('manual validity', () {
    test('weekly, monthly and yearly resolve to a real date', () {
      final from = DateTime(2026, 11, 24);
      expect(
        manualValidUntil(recurrence: ManualRecurrence.weekly, from: from),
        DateTime(2026, 12, 1),
      );
      expect(
        manualValidUntil(recurrence: ManualRecurrence.monthly, from: from),
        DateTime(2026, 12, 24),
      );
      expect(
        manualValidUntil(recurrence: ManualRecurrence.yearly, from: from),
        DateTime(2027, 11, 24),
      );
    });

    test('the month rolls over instead of clamping', () {
      expect(
        manualValidUntil(
          recurrence: ManualRecurrence.monthly,
          from: DateTime(2026, 12, 20),
        ),
        DateTime(2027, 1, 20),
      );
    });

    test('a manual counts from City Hall approval', () {
      final manual = AssignmentManual.fromDoc('m1', {
        'title': 'Zone 3',
        'driverName': 'Ramon Dela Cruz',
        'plateNumber': 'SK 4821',
        'startTime': '08:00',
        'recurrence': 'weekly',
        'status': 'approved',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 20)),
        'approvedAt': Timestamp.fromDate(DateTime(2026, 11, 24)),
        'createdBy': 'i1',
      });

      expect(manual!.validUntil, DateTime(2026, 12, 1));
    });
  });

  group('manual areas', () {
    test('every listed resident area has a pre-made route', () {
      final expected = [
        for (final name in ResidentAreas.all)
          if (!ResidentAreas.isOther(name)) name,
      ];
      expect(kManualAreas, hasLength(expected.length));
      expect([for (final area in kManualAreas) area.name], expected);
    });

    test('every area pin sits inside Batasan Hills', () {
      for (final area in kManualAreas) {
        expect(area.center.latitude, inInclusiveRange(14.668, 14.697));
        expect(area.center.longitude, inInclusiveRange(121.083, 121.112));
      }
    });

    test('the run joins the pins in the order they were picked', () {
      final picked = [kManualAreas[2], kManualAreas[0], kManualAreas[1]];
      expect(manualRouteForAreas(picked), [
        picked[0].center,
        picked[1].center,
        picked[2].center,
      ]);
    });
  });

  group('assignment manual', () {
    test('reads the schedule and keeps the generated ticket id', () {
      final manual = AssignmentManual.fromDoc('m1', {
        'title': 'Zone 3 schedule',
        'driverId': 'd1',
        'driverName': 'Ramon Dela Cruz',
        'truckId': 'truck-01',
        'plateNumber': 'SK 4821',
        'wheelers': 8,
        'routes': ['Sampaguita', 'Mabini'],
        'days': [1, 3, 5],
        'startTime': '06:00',
        'recurrence': 'weekly',
        'status': 'pendingApproval',
        'ticketId': 'tt1',
        'createdBy': 'i1',
        'createdByName': 'Iswim',
      });

      expect(manual, isNotNull);
      expect(manual!.scheduleLabel, 'Mon, Wed, Fri · 06:00 · Weekly');
      expect(manual.ticketId, 'tt1');
      expect(manual.isApproved, isFalse);
      expect(manual.maxRoutes, 4);
      expect(manual.assignmentCount, 1);
      expect(manual.allRoutes, ['Sampaguita', 'Mabini']);
    });

    test('reads a bulk roster and keeps every driver row', () {
      final manual = AssignmentManual.fromDoc('m2', {
        'title': 'Bulk schedule',
        'status': 'pendingApproval',
        'createdBy': 'i1',
        'createdByName': 'Iswim',
        'assignments': [
          {
            'driverId': 'd1',
            'driverName': 'Arwin Decena',
            'truckId': 'truck-06',
            'plateNumber': 'SH 3372',
            'wheelers': 4,
            'routes': ['Filinvest 1', 'Filinvest 2'],
            'days': [1, 3, 5],
            'startTime': '08:00',
            'recurrence': 'weekly',
          },
          {
            'driverId': 'd4',
            'driverName': 'Ben Cruz',
            'truckId': 'truck-10',
            'plateNumber': 'SK 4410',
            'wheelers': 10,
            'routes': [
              'Sampaguita',
              'Mabini Ave',
              'Kabihasnan St',
              'Kaluguran St',
              'Rizal Ave',
            ],
            'days': [2, 4, 6],
            'startTime': '18:00',
            'recurrence': 'yearly',
          },
        ],
        'ticketIds': ['tt1', 'tt2'],
      });

      expect(manual, isNotNull);
      expect(manual!.assignmentCount, 2);
      expect(manual.driverName, 'Arwin Decena');
      expect(manual.ticketIds, ['tt1', 'tt2']);
      expect(manual.allRoutes, hasLength(7));
      expect(manual.runsOn(DateTime(2026, 11, 2)), isTrue);
      expect(manual.runsOn(DateTime(2026, 11, 3)), isTrue);
      expect(manual.runsOn(DateTime(2026, 11, 8)), isFalse);
    });
  });

  group('assignment trip ticket', () {
    test('parses kind, routes, days and the approval flag', () {
      final ticket = TripTicket.fromDoc('tt1', {
        'code': 'TT-2026-0001',
        'truckId': 'truck-01',
        'plateNumber': 'SK 4821',
        'wheelers': 8,
        'driverId': 'd1',
        'driverName': 'Ramon Dela Cruz',
        'route': 'Sampaguita · Mabini',
        'status': 'issued',
        'kind': 'assignment',
        'routes': ['Sampaguita', 'Mabini'],
        'days': [1, 3, 5],
        'recurrence': 'weekly',
        'windowStart': '06:00',
        'approvalPending': true,
        'assignmentId': 'm1',
      });

      expect(ticket, isNotNull);
      expect(ticket!.isAssignment, isTrue);
      expect(ticket.approvalPending, isTrue);
      expect(ticket.awaitingSignature, TicketStatusSigner.cityHall);
      expect(ticket.needsDriver, isFalse);
      expect(ticket.waveLabel, 'Manual');
      expect(ticket.scheduleLabel, 'Mon, Wed, Fri · 06:00 · Weekly');
      expect(ticket.routesLabel, 'Sampaguita · Mabini');
    });

    test('the start gate follows the manual roster', () {
      TripTicket ticket({
        List<int> days = const [1],
        ManualRecurrence recurrence = ManualRecurrence.weekly,
        DateTime? createdAt,
        String windowStart = '06:00',
      }) => TripTicket(
        id: 'tt1',
        code: 'TT-2026-0001',
        wave: 1,
        truckId: 'truck-01',
        plateNumber: 'SK 4821',
        wheelers: 6,
        driverId: 'd1',
        driverName: 'Ramon Dela Cruz',
        route: '',
        zone: '',
        date: '',
        windowStart: windowStart,
        windowEnd: '',
        notes: '',
        status: TicketStatus.valid,
        createdBy: 'i1',
        kind: TicketKind.assignment,
        routes: const ['Sampaguita'],
        days: days,
        recurrence: recurrence,
        createdAt: createdAt,
      );

      final weekly = ticket();
      expect(weekly.runsOn(DateTime(2026, 11, 2)), isTrue);
      expect(weekly.runsOn(DateTime(2026, 11, 3)), isFalse);
      expect(weekly.nextRun, isNotNull);

      final monthly = ticket(
        recurrence: ManualRecurrence.monthly,
        createdAt: DateTime(2026, 11, 5),
      );
      expect(monthly.runsOn(DateTime(2026, 11, 9)), isTrue);
      expect(monthly.runsOn(DateTime(2026, 12, 7)), isFalse);

      final yearly = ticket(
        recurrence: ManualRecurrence.yearly,
        days: const [2, 4, 6],
        createdAt: DateTime(2026, 11, 5),
      );
      // The bug that locked the driver out: a mid-month Tuesday is still a
      // working day on a yearly manual.
      expect(yearly.runsOn(DateTime(2026, 11, 24)), isTrue);
      expect(yearly.runsOn(DateTime(2027, 11, 9)), isFalse);
    });

    test('the start gate waits for the shift hour', () {
      final ticket = TripTicket(
        id: 'tt1',
        code: 'TT-2026-0001',
        wave: 1,
        truckId: 'truck-01',
        plateNumber: 'SK 4821',
        wheelers: 6,
        driverId: 'd1',
        driverName: 'Arwin Decena',
        route: '',
        zone: '',
        date: '',
        windowStart: '08:00',
        windowEnd: '',
        notes: '',
        status: TicketStatus.valid,
        createdBy: 'i1',
        kind: TicketKind.assignment,
        routes: const ['Kagawad Road'],
        days: const [2, 4, 6],
        recurrence: ManualRecurrence.yearly,
        createdAt: DateTime(2026, 11, 5),
      );

      // 12:44 AM on a working day is still too early.
      expect(ticket.isShiftOpen(DateTime(2026, 11, 24, 0, 44)), isFalse);
      expect(ticket.isShiftOpen(DateTime(2026, 11, 24, 7, 59)), isFalse);
      expect(ticket.isShiftOpen(DateTime(2026, 11, 24, 8, 0)), isTrue);
      expect(ticket.isShiftOpen(DateTime(2026, 11, 24, 14, 30)), isTrue);
      // 8 AM on a non-working day is still closed.
      expect(ticket.isShiftOpen(DateTime(2026, 11, 25, 9, 0)), isFalse);
    });

    test('route points survive the write and read', () {
      final ticket = TripTicket.fromDoc('tt1', {
        'code': 'TT-2026-0001',
        'truckId': 'truck-01',
        'plateNumber': 'SK 4821',
        'wheelers': 6,
        'driverId': 'd1',
        'driverName': 'Ramon Dela Cruz',
        'status': 'valid',
        'kind': 'assignment',
        'routes': ['Sampaguita', 'Mabini'],
        'routePoints': [
          {'name': 'Sampaguita', 'lat': 14.68, 'lng': 121.09},
          {'name': 'Mabini', 'lat': 14.69, 'lng': 121.10},
          {'name': '', 'lat': 14.7, 'lng': 121.11},
        ],
        'days': [1],
        'recurrence': 'weekly',
        'windowStart': '06:00',
      });

      expect(ticket, isNotNull);
      expect(ticket!.routePoints, hasLength(2));
      expect(ticket.routePoints.first.name, 'Sampaguita');
      expect(ticket.routePoints.last.latitude, 14.69);

      final written = ticket.toMap()['routePoints'] as List;
      expect(written, hasLength(2));
      expect(written.first, {
        'name': 'Sampaguita',
        'lat': 14.68,
        'lng': 121.09,
      });
    });
  });

  group('shift calendar', () {
    AssignmentManual manual({
      List<int> days = const [1],
      String recurrence = 'weekly',
      String status = 'approved',
      DateTime? createdAt,
    }) => AssignmentManual(
      id: 'm1',
      title: 'Zone 3 schedule',
      driverId: 'd1',
      driverName: 'Ramon Dela Cruz',
      truckId: 'truck-01',
      plateNumber: 'SK 4821',
      wheelers: 6,
      routes: const ['Sampaguita'],
      days: days,
      startTime: '06:00',
      recurrence: ManualRecurrenceX.fromName(recurrence),
      status: AssignmentManualStatusX.fromName(status),
      createdBy: 'i1',
      createdByName: 'Iswim',
      createdAt: createdAt,
    );

    test('a weekly manual runs every matching weekday', () {
      final weekly = manual();
      // November 2026: the 2nd, 9th, 16th, 23rd and 30th are Mondays.
      for (final day in [2, 9, 16, 23, 30]) {
        expect(weekly.runsOn(DateTime(2026, 11, day)), isTrue);
      }
      expect(weekly.runsOn(DateTime(2026, 11, 3)), isFalse);
      expect(weekly.runsOn(DateTime(2026, 11, 21)), isFalse);
    });

    test('a monthly manual keeps the weekly pattern for one month', () {
      final monthly = manual(
        recurrence: 'monthly',
        createdAt: DateTime(2026, 11, 5),
      );
      expect(monthly.runsOn(DateTime(2026, 11, 9)), isTrue);
      expect(monthly.runsOn(DateTime(2026, 11, 30)), isTrue);
      // One month from 5 Nov ends on 5 Dec.
      expect(monthly.runsOn(DateTime(2026, 12, 7)), isFalse);
      // Nothing before the manual existed.
      expect(monthly.runsOn(DateTime(2026, 11, 2)), isFalse);
    });

    test('a yearly manual keeps the weekly pattern for a year', () {
      final yearly = manual(
        recurrence: 'yearly',
        createdAt: DateTime(2026, 11, 5),
      );
      // A Monday in the middle of the month is still a working day.
      expect(yearly.runsOn(DateTime(2026, 11, 23)), isTrue);
      expect(yearly.runsOn(DateTime(2027, 3, 1)), isTrue);
      // One year from 5 Nov 2026 ends on 5 Nov 2027.
      expect(yearly.runsOn(DateTime(2027, 11, 8)), isFalse);
    });

    test('a cancelled manual never shows on the calendar', () {
      final cancelled = manual(status: 'cancelled');
      expect(cancelled.runsOn(DateTime(2026, 11, 2)), isFalse);
    });
  });

  group('manual pdf', () {
    test('writes a valid one-page pdf with a matching xref', () {
      final bytes = buildSimplePdf('Collection manual', [
        'Driver: Ramon Dela Cruz',
        'Plate number: SK 4821',
      ]);
      final text = latin1.decode(bytes);

      expect(text.startsWith('%PDF-1.4'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);

      final startxref = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!,
      );
      expect(text.substring(startxref, startxref + 4), 'xref');
      expect(pdfDataUrl(bytes), startsWith('data:application/pdf;base64,'));
    });
  });
}
