import 'package:eco_connect/features/cityhall/models/ticket_queue.dart';
import 'package:eco_connect/features/tickets/models/trip_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

/// City Hall signs a bulk manual once, so the queue must show a manual once.
/// These tests pin that grouping: three drivers on one manual are one row in
/// the queue, while a plain trip ticket still stands on its own.
void main() {
  group('ticket queue grouping', () {
    test('every driver on one manual collapses into a single entry', () {
      final entries = groupTicketsByManual([
        _ticket(id: 't1', code: 'TT-1', manualId: 'm1', driver: 'Ramon'),
        _ticket(id: 't2', code: 'TT-2', manualId: 'm1', driver: 'Jose'),
        _ticket(id: 't3', code: 'TT-3', manualId: 'm1', driver: 'Maria'),
      ]);

      expect(entries.length, 1);
      expect(entries.single.isManual, isTrue);
      expect(entries.single.tickets.length, 3);
    });

    test('a lone trip ticket keeps its own card', () {
      final entries = groupTicketsByManual([
        _ticket(id: 't1', code: 'TT-1', driver: 'Ramon'),
        _ticket(id: 't2', code: 'TT-2', driver: 'Jose'),
      ]);

      expect(entries.length, 2);
      expect(entries.every((entry) => !entry.isManual), isTrue);
    });

    test('a manual and a plain ticket stay apart, newest first', () {
      final entries = groupTicketsByManual([
        _ticket(id: 't1', code: 'TT-1', manualId: 'm1', driver: 'Ramon'),
        _ticket(id: 't2', code: 'TT-2', driver: 'Jose'),
        _ticket(id: 't3', code: 'TT-3', manualId: 'm1', driver: 'Maria'),
      ]);

      expect(entries.length, 2);
      expect(entries.first.isManual, isTrue);
      expect(entries.first.lead.code, 'TT-1');
      expect(entries.last.isManual, isFalse);
      expect(entries.last.lead.code, 'TT-2');
    });

    test('the card opens a row that is still waiting for the signature', () {
      final entries = groupTicketsByManual([
        _ticket(id: 't1', code: 'TT-1', manualId: 'm1', pending: false),
        _ticket(id: 't2', code: 'TT-2', manualId: 'm1', pending: true),
      ]);

      // Signing the first row would be a no-op once it has moved on, so the
      // entry points at the row that still approves the roster.
      expect(entries.single.lead.code, 'TT-2');
      expect(entries.single.lead.approvalPending, isTrue);
    });

    test('an empty queue produces no entries', () {
      expect(groupTicketsByManual(const []), isEmpty);
    });
  });
}

TripTicket _ticket({
  required String id,
  required String code,
  String? manualId,
  String driver = 'Ramon Dela Cruz',
  bool pending = true,
}) {
  return TripTicket(
    id: id,
    code: code,
    wave: 1,
    truckId: 'truck-$id',
    plateNumber: 'ABC 1234',
    wheelers: 4,
    driverId: 'driver-$id',
    driverName: driver,
    route: 'Purok 1 – Purok 4',
    zone: 'Zone 3',
    date: '2026-11-14',
    windowStart: '07:00',
    windowEnd: '09:00',
    notes: '',
    status: pending ? TicketStatus.issued : TicketStatus.valid,
    createdBy: 'iswim-1',
    assignmentId: manualId,
    approvalPending: pending,
    createdAt: DateTime(2026, 11, 14, 6),
  );
}
