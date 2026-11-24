import '../../tickets/models/trip_ticket.dart';

/// One row of City Hall's ticket queue.
///
/// A lone trip ticket stands for itself. A bulk collection manual writes one
/// trip ticket per driver but is a single document to the DSQC, so all of its
/// rows collapse into one entry here — City Hall signs the manual once.
class TicketQueueEntry {
  const TicketQueueEntry({required this.tickets});

  /// The pending rows this entry covers, in queue order. Never empty.
  final List<TripTicket> tickets;

  /// More than one row means a manual roster rather than a single trip.
  bool get isManual => tickets.length > 1;

  /// The row the card opens.
  ///
  /// A manual is signed through any of its pending rows and that signature
  /// covers the whole roster, so an approval-pending row is preferred over one
  /// that already moved on.
  TripTicket get lead {
    for (final ticket in tickets) {
      if (ticket.approvalPending) return ticket;
    }
    return tickets.first;
  }
}

/// Groups pending tickets by the manual that produced them.
///
/// Tickets with no `assignmentId` keep a card of their own. Order follows the
/// first appearance of each manual, so the queue stays newest-first.
List<TicketQueueEntry> groupTicketsByManual(List<TripTicket> tickets) {
  final groups = <String, List<TripTicket>>{};
  for (final ticket in tickets) {
    final manualId = ticket.assignmentId?.trim() ?? '';
    final key = manualId.isEmpty ? 'ticket:${ticket.id}' : 'manual:$manualId';
    (groups[key] ??= <TripTicket>[]).add(ticket);
  }
  return [
    for (final rows in groups.values) TicketQueueEntry(tickets: rows),
  ];
}
