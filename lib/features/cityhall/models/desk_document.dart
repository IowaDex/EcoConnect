import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../memos/services/memo_service.dart';
import '../../tickets/models/trip_ticket.dart';

/// The office a document came from, as the City Hall desk groups it.
enum DeskCategory { barangay, iswim, driver }

extension DeskCategoryX on DeskCategory {
  /// Filter label.
  String get label => switch (this) {
        DeskCategory.barangay => 'Barangay',
        DeskCategory.iswim => 'ISWIM',
        DeskCategory.driver => 'Truck Drivers',
      };

  /// Singular label used on a card.
  String get singular => switch (this) {
        DeskCategory.barangay => 'Barangay',
        DeskCategory.iswim => 'ISWIM',
        DeskCategory.driver => 'Truck Driver',
      };

  /// Sender role shown under the sender's name.
  String get roleLabel => switch (this) {
        DeskCategory.barangay => 'Barangay Staff',
        DeskCategory.iswim => 'ISWIM',
        DeskCategory.driver => 'Truck Driver',
      };

  IconData get icon => switch (this) {
        DeskCategory.barangay => Icons.account_balance_outlined,
        DeskCategory.iswim => Icons.business_center_outlined,
        DeskCategory.driver => Icons.local_shipping_outlined,
      };

  /// Subtle category accent. Greens stay for the barangay, blue for Iswim,
  /// amber for the fleet so the three groups are distinguishable at a glance.
  Color get color => switch (this) {
        DeskCategory.barangay => AppColors.primary,
        DeskCategory.iswim => const Color(0xFF1565C0),
        DeskCategory.driver => AppColors.warning,
      };
}

/// The kind of document in the desk queue.
enum DeskDocumentKind {
  tripTicket,
  memo,
  endorsement,
  announcement,
  manualRequest,
}

extension DeskDocumentKindX on DeskDocumentKind {
  String get label => switch (this) {
        DeskDocumentKind.tripTicket => 'Trip Ticket',
        DeskDocumentKind.memo => 'Memo',
        DeskDocumentKind.endorsement => 'Endorsement',
        DeskDocumentKind.announcement => 'Announcement',
        DeskDocumentKind.manualRequest => 'Manual Request',
      };
}

/// The status shown on a card. The same record can carry a different label in
/// the two sections (a completed ticket is "Signed" in For Signature and
/// "Completed" in Received), so the builder chooses the status per section.
enum DeskDocumentStatus {
  awaitingSignature,
  signed,
  rejected,
  returnedForRevision,
  newDocument,
  received,
  underReview,
  acknowledged,
  completed,
}

extension DeskDocumentStatusX on DeskDocumentStatus {
  String get label => switch (this) {
        DeskDocumentStatus.awaitingSignature => 'Awaiting Signature',
        DeskDocumentStatus.signed => 'Signed',
        DeskDocumentStatus.rejected => 'Rejected',
        DeskDocumentStatus.returnedForRevision => 'Returned for Revision',
        DeskDocumentStatus.newDocument => 'New',
        DeskDocumentStatus.received => 'Received',
        DeskDocumentStatus.underReview => 'Under Review',
        DeskDocumentStatus.acknowledged => 'Acknowledged',
        DeskDocumentStatus.completed => 'Completed',
      };

  Color get color => switch (this) {
        DeskDocumentStatus.awaitingSignature => AppColors.warning,
        DeskDocumentStatus.signed => AppColors.primary,
        DeskDocumentStatus.rejected => AppColors.error,
        DeskDocumentStatus.returnedForRevision => AppColors.warning,
        DeskDocumentStatus.newDocument => const Color(0xFF1565C0),
        DeskDocumentStatus.received => AppColors.moss,
        DeskDocumentStatus.underReview => AppColors.warning,
        DeskDocumentStatus.acknowledged => AppColors.primary,
        DeskDocumentStatus.completed => AppColors.primary,
      };

  IconData get icon => switch (this) {
        DeskDocumentStatus.awaitingSignature => Icons.draw_outlined,
        DeskDocumentStatus.signed => Icons.verified_outlined,
        DeskDocumentStatus.rejected => Icons.cancel_outlined,
        DeskDocumentStatus.returnedForRevision => Icons.undo_rounded,
        DeskDocumentStatus.newDocument => Icons.fiber_new_outlined,
        DeskDocumentStatus.received => Icons.mark_email_read_outlined,
        DeskDocumentStatus.underReview => Icons.visibility_outlined,
        DeskDocumentStatus.acknowledged => Icons.verified_rounded,
        DeskDocumentStatus.completed => Icons.task_alt_rounded,
      };

  bool get isPendingSignature =>
      this == DeskDocumentStatus.awaitingSignature;
}

/// The status selector above the For Signature list. The active list defaults
/// to [awaiting]; signed, rejected and returned records are opt-in so the
/// queue never mixes finished work with work still waiting.
enum SignatureFilter { awaiting, signed, rejected, returned }

extension SignatureFilterX on SignatureFilter {
  String get label => switch (this) {
        SignatureFilter.awaiting => 'Awaiting Signature',
        SignatureFilter.signed => 'Signed',
        SignatureFilter.rejected => 'Rejected',
        SignatureFilter.returned => 'Returned for Revision',
      };

  DeskDocumentStatus get status => switch (this) {
        SignatureFilter.awaiting => DeskDocumentStatus.awaitingSignature,
        SignatureFilter.signed => DeskDocumentStatus.signed,
        SignatureFilter.rejected => DeskDocumentStatus.rejected,
        SignatureFilter.returned => DeskDocumentStatus.returnedForRevision,
      };
}

/// The barangay this deployment serves.
///
/// Provisioned government accounts carry no `barangay` field, so a memo sent
/// by the barangay desk would otherwise show a blank origin. This is the same
/// barangay every map and truck record in the app is scoped to.
const kDeskBarangay = 'Barangay Batasan Hills';

/// A person resolved from `users/{uid}`, used so the desk shows the account's
/// current full name and barangay rather than a label copied at submission.
class DeskPerson {
  const DeskPerson({
    required this.uid,
    required this.name,
    this.barangay = '',
    this.role = '',
  });

  final String uid;
  final String name;
  final String barangay;
  final String role;
}

/// One row in either desk section. It wraps the real trip ticket or memo, so
/// the card can open the underlying document and sign it through the existing
/// service.
class DeskDocument {
  const DeskDocument({
    required this.id,
    required this.kind,
    required this.category,
    required this.title,
    required this.reference,
    required this.displayReference,
    required this.senderName,
    required this.senderRole,
    required this.department,
    required this.date,
    required this.dateCaption,
    required this.status,
    this.area = '',
    this.route = '',
    this.truck = '',
    this.driverName = '',
    this.hasAttachment = false,
    this.canSign = false,
    this.openRoute = '',
    this.ticket,
    this.memo,
  });

  final String id;
  final DeskDocumentKind kind;
  final DeskCategory category;

  /// Human title: the memo subject or the trip's route.
  final String title;

  /// Stable reference used for search (ticket code or memo id).
  final String reference;

  /// Short reference shown on the card.
  final String displayReference;

  final String senderName;
  final String senderRole;
  final String department;

  /// The date relevant to the section (submitted, signed or received).
  final DateTime? date;
  final String dateCaption;

  final DeskDocumentStatus status;

  /// Barangay / collection area.
  final String area;

  /// Streets covered by a trip ticket.
  final String route;

  /// Assigned truck plate.
  final String truck;

  final String driverName;
  final bool hasAttachment;
  final bool canSign;

  /// Route that opens the underlying document.
  final String openRoute;

  final TripTicket? ticket;
  final Memo? memo;

  bool matchesCategory(DeskCategory? category) =>
      category == null || this.category == category;

  bool matchesSignatureFilter(SignatureFilter filter) =>
      status == filter.status;

  /// Case-insensitive partial match across every field the desk can search:
  /// title, reference, sender, department, driver, barangay, area and type.
  bool matchesSearch(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return true;
    final haystack = <String>[
      title,
      reference,
      displayReference,
      senderName,
      senderRole,
      department,
      area,
      route,
      truck,
      driverName,
      kind.label,
      status.label,
      if (ticket != null) ticket!.code,
      if (ticket != null) ticket!.plateNumber,
      if (memo != null) memo!.fromName,
      if (memo != null) memo!.fromRole,
    ];
    return haystack.any((value) => value.toLowerCase().contains(term));
  }
}

/// The two lists the City Hall desk renders.
class CityHallDocuments {
  const CityHallDocuments({
    required this.forSignature,
    required this.received,
  });

  final List<DeskDocument> forSignature;
  final List<DeskDocument> received;

  static const empty = CityHallDocuments(
    forSignature: <DeskDocument>[],
    received: <DeskDocument>[],
  );

  int get pendingSignatures => forSignature
      .where((document) => document.status.isPendingSignature)
      .length;
}

/// Builds both desk lists from the real ticket and memo streams.
///
/// * For Signature holds documents City Hall must act on now (awaiting), plus
///   the records that already passed through the desk when the user selects a
///   different status filter.
/// * Received holds completed tickets and every memo addressed to City Hall,
///   with New / Received / Acknowledged mapped from the stored status.
///
/// Nothing here writes to Firestore; filtering is a pure function of the
/// retrieved records.
CityHallDocuments buildCityHallDocuments({
  required List<TripTicket> tickets,
  required List<Memo> memos,
  Map<String, DeskPerson> people = const {},
}) {
  final forSignature = <DeskDocument>[];
  final received = <DeskDocument>[];
  final signatureKeys = <String>{};
  final receivedKeys = <String>{};

  void addSignature(DeskDocument document) {
    if (signatureKeys.add('${document.kind.name}:${document.id}')) {
      forSignature.add(document);
    }
  }

  void addReceived(DeskDocument document) {
    if (receivedKeys.add('${document.kind.name}:${document.id}')) {
      received.add(document);
    }
  }

  for (final ticket in tickets) {
    final person = people[ticket.driverId];
    final driverName = _firstNonEmpty([
      person?.name,
      ticket.driverName,
      'Driver name unavailable',
    ]);

    switch (ticket.status) {
      case TicketStatus.iswimSigned:
        addSignature(
          _ticketDocument(
            ticket,
            driverName,
            DeskDocumentStatus.awaitingSignature,
            dateCaption: 'Submitted',
            canSign: true,
          ),
        );
      case TicketStatus.completed:
        addSignature(
          _ticketDocument(
            ticket,
            driverName,
            DeskDocumentStatus.signed,
            dateCaption: 'Signed',
          ),
        );
        addReceived(
          _ticketDocument(
            ticket,
            driverName,
            DeskDocumentStatus.completed,
            dateCaption: 'Received',
          ),
        );
      case TicketStatus.rejected:
        addSignature(
          _ticketDocument(
            ticket,
            driverName,
            DeskDocumentStatus.rejected,
            dateCaption: 'Rejected',
          ),
        );
      case TicketStatus.revisionRequired:
        addSignature(
          _ticketDocument(
            ticket,
            driverName,
            DeskDocumentStatus.returnedForRevision,
            dateCaption: 'Returned',
          ),
        );
      default:
        // Issued, accepted, running and barangay-signed tickets are not at
        // City Hall's signature step yet.
        break;
    }
  }

  for (final memo in memos) {
    if (memo.toChannel != 'cityHall') continue;

    final category = memo.fromRole == 'barangay'
        ? DeskCategory.barangay
        : DeskCategory.iswim;
    final person = people[memo.fromUid];
    final senderName = _firstNonEmpty([
      person?.name,
      memo.fromName,
      category.label,
    ]);
    final barangay = person?.barangay ?? '';

    if (memo.isSigned) {
      addSignature(
        _memoDocument(
          memo,
          category,
          senderName,
          barangay,
          DeskDocumentStatus.signed,
          dateCaption: 'Signed',
        ),
      );
      addReceived(
        _memoDocument(
          memo,
          category,
          senderName,
          barangay,
          DeskDocumentStatus.acknowledged,
          dateCaption: 'Received',
        ),
      );
    } else {
      addSignature(
        _memoDocument(
          memo,
          category,
          senderName,
          barangay,
          DeskDocumentStatus.awaitingSignature,
          dateCaption: 'Submitted',
          canSign: true,
        ),
      );
      addReceived(
        _memoDocument(
          memo,
          category,
          senderName,
          barangay,
          memo.status == MemoStatus.received
              ? DeskDocumentStatus.received
              : DeskDocumentStatus.newDocument,
          dateCaption:
              memo.status == MemoStatus.received ? 'Received' : 'Arrived',
          // An unsigned memo in the inbox still needs the City Hall
          // acknowledgement, so the card keeps the action available.
          canSign: true,
        ),
      );
    }
  }

  forSignature.sort(_newestFirst);
  received.sort(_newestFirst);

  return CityHallDocuments(forSignature: forSignature, received: received);
}

DeskDocument _ticketDocument(
  TripTicket ticket,
  String driverName,
  DeskDocumentStatus status, {
  required String dateCaption,
  bool canSign = false,
}) {
  final date = switch (dateCaption) {
    'Signed' || 'Received' =>
      ticket.completedAt ?? ticket.submittedAt ?? ticket.createdAt,
    'Rejected' || 'Returned' =>
      ticket.history.isNotEmpty ? ticket.history.last.at : ticket.createdAt,
    _ => ticket.submittedAt ?? ticket.createdAt,
  };

  final route = ticket.route.trim();
  return DeskDocument(
    id: ticket.id,
    kind: DeskDocumentKind.tripTicket,
    category: DeskCategory.driver,
    title: route.isEmpty ? 'Trip ticket ${ticket.code}' : route,
    reference: ticket.code,
    displayReference: ticket.code,
    senderName: driverName,
    senderRole: DeskCategory.driver.roleLabel,
    department: DeskCategory.driver.label,
    area: ticket.zone.trim(),
    route: route,
    truck: ticket.plateNumber.trim(),
    driverName: driverName,
    date: date,
    dateCaption: dateCaption,
    status: status,
    canSign: canSign,
    openRoute: '/tickets/${ticket.id}',
    ticket: ticket,
  );
}

DeskDocument _memoDocument(
  Memo memo,
  DeskCategory category,
  String senderName,
  String barangay,
  DeskDocumentStatus status, {
  required String dateCaption,
  bool canSign = false,
}) {
  final date = switch (dateCaption) {
    'Signed' => memo.acknowledgedAt ?? memo.receivedAt ?? memo.createdAt,
    'Received' => memo.receivedAt ?? memo.createdAt,
    _ => memo.createdAt,
  };

  // The deployment serves one barangay and provisioned government accounts
  // have no `barangay` field, so the operational barangay is shown when the
  // sender's profile does not name one.
  final area = _firstNonEmpty([
    barangay,
    if (category == DeskCategory.barangay) kDeskBarangay,
  ]);

  return DeskDocument(
    id: memo.id,
    kind: _kindOf(memo.kind),
    category: category,
    title: memo.subject,
    reference: memo.id,
    displayReference: _memoReference(memo.id),
    senderName: senderName,
    senderRole: category.roleLabel,
    department: category.label,
    area: area,
    date: date,
    dateCaption: dateCaption,
    status: status,
    hasAttachment: memo.attachment != null,
    canSign: canSign,
    openRoute: '/memo/${memo.id}',
    memo: memo,
  );
}

DeskDocumentKind _kindOf(MemoKind kind) => switch (kind) {
      MemoKind.memo => DeskDocumentKind.memo,
      MemoKind.endorsement => DeskDocumentKind.endorsement,
      MemoKind.announcement => DeskDocumentKind.announcement,
      MemoKind.manualRequest => DeskDocumentKind.manualRequest,
    };

/// `MEMO-1A2B3C4D` — a stable, readable reference derived from the document
/// id. Memos have no stored counter, so the id is the source of truth.
String _memoReference(String id) {
  final short = id.length > 8 ? id.substring(0, 8) : id;
  return 'MEMO-${short.toUpperCase()}';
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

int _newestFirst(DeskDocument a, DeskDocument b) {
  final left = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  final right = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  return right.compareTo(left);
}
