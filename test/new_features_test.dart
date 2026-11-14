import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/models/waste_category.dart';
import 'package:eco_connect/core/utils/image_payload.dart';
import 'package:eco_connect/features/announcements/models/announcement.dart';
import 'package:eco_connect/features/cityhall/models/desk_document.dart';
import 'package:eco_connect/features/collection_points/models/collection_point.dart';
import 'package:eco_connect/features/driver/services/driver_session_service.dart';
import 'package:eco_connect/features/events/models/community_event.dart';
import 'package:eco_connect/features/memos/services/memo_service.dart';
import 'package:eco_connect/features/requests/models/collection_request.dart';
import 'package:eco_connect/features/tickets/models/trip_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('waste categories', () {
    test('round-trips wire names and falls back safely', () {
      expect(WasteCategoryX.fromName('electronic'), WasteCategory.electronic);
      expect(WasteCategoryX.fromName('biodegradable'),
          WasteCategory.biodegradable);
      expect(WasteCategoryX.fromName('not-a-category'), WasteCategory.residual);
      expect(WasteCategoryX.fromName(null), WasteCategory.residual);
    });

    test('every category has display metadata', () {
      for (final category in WasteCategory.values) {
        expect(category.label, isNotEmpty);
        expect(category.shortLabel, isNotEmpty);
        expect(category.hint, isNotEmpty);
      }
    });
  });

  group('upload codec', () {
    test('accepts only documented extensions', () {
      expect(UploadCodec.isAllowedDocument('id.pdf'), isTrue);
      expect(UploadCodec.isAllowedDocument('photo.JPG'), isTrue);
      expect(UploadCodec.isAllowedDocument('photo.png'), isTrue);
      expect(UploadCodec.isAllowedDocument('notes.docx'), isFalse);
      expect(UploadCodec.isAllowedDocument('noextension'), isFalse);
    });

    test('reads the extension after the last dot', () {
      expect(UploadCodec.extensionOf('my.id.card.PNG'), 'png');
      expect(UploadCodec.extensionOf('archive.tar.gz'), 'gz');
    });
  });

  group('memos', () {
    test('round-trips the sent state and the recipient label', () {
      final memo = Memo.fromDoc('m1', {
        'kind': 'memo',
        'subject': 'Collection schedule',
        'body': 'Please review the attached schedule.',
        'fromName': 'Ivy',
        'fromRole': 'iswim',
        'fromUid': 'ivy',
        'toChannel': 'cityHall',
        'status': 'sent',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 14, 9, 30)),
      })!;

      expect(memo.kind, MemoKind.memo);
      expect(memo.status, MemoStatus.sent);
      expect(memo.recipientLabel, 'City Hall');
      expect(memo.isSigned, isFalse);
      expect(memo.isEditable, isTrue);
      expect(memo.createdAt, DateTime(2026, 11, 14, 9, 30));
    });

    test('a signed memo carries the signer, time and drawn signature', () {
      final memo = Memo.fromDoc('m2', {
        'subject': 'Signed memo',
        'body': 'Body',
        'fromUid': 'ivy',
        'toChannel': 'cityHall',
        'status': 'acknowledged',
        'receivedAt': Timestamp.fromDate(DateTime(2026, 11, 14, 10)),
        'acknowledgedAt': Timestamp.fromDate(DateTime(2026, 11, 14, 11)),
        'acknowledgedByUid': 'carl',
        'acknowledgedByName': 'Carl',
        'acknowledgementSignature': 'data:image/png;base64,iVBORw0KGgo=',
      })!;

      expect(memo.isSigned, isTrue);
      expect(memo.isEditable, isFalse);
      expect(memo.acknowledgedByUid, 'carl');
      expect(memo.acknowledgedByName, 'Carl');
      expect(memo.acknowledgementSignature, startsWith('data:image/png'));
      expect(memo.receivedAt, DateTime(2026, 11, 14, 10));
      expect(memo.acknowledgedAt, DateTime(2026, 11, 14, 11));
    });

    test('records written before attachments were typed keep their photo', () {
      final memo = Memo.fromDoc('m3', {
        'subject': 'Legacy',
        'body': 'Body',
        'fromUid': 'ivy',
        'toChannel': 'cityHall',
        'photo': 'data:image/jpeg;base64,AAAA',
      })!;

      expect(memo.attachment, isNotNull);
      expect(memo.attachment!.dataUrl, 'data:image/jpeg;base64,AAAA');
      expect(memo.attachment!.isPdf, isFalse);
    });

    test('a new memo is always written as sent with its attachment', () {
      const payload = UploadPayload(
        dataUrl: 'data:application/pdf;base64,AAAA',
        fileName: 'schedule.pdf',
        mimeType: 'application/pdf',
        bytes: 4,
      );
      const memo = Memo(
        id: '',
        kind: MemoKind.endorsement,
        subject: 'Endorsement',
        body: 'Body',
        fromName: 'Carl',
        fromRole: 'cityHall',
        fromUid: 'carl',
        toChannel: 'barangay',
        attachment: payload,
      );

      final map = memo.toMap();
      expect(map['status'], 'sent');
      expect(map['kind'], 'endorsement');
      expect(map['toChannel'], 'barangay');
      expect((map['attachment'] as Map)['fileName'], 'schedule.pdf');
    });

    test('unknown wire values fall back instead of throwing', () {
      expect(MemoStatusX.fromName('nonsense'), MemoStatus.sent);
      expect(MemoStatusX.fromName(null), MemoStatus.sent);
      expect(MemoKindX.fromName('nonsense'), MemoKind.memo);
    });
  });

  group('collection requests', () {
    test('parses a Firestore document and keeps its history', () {
      final request = CollectionRequest.fromDoc('req-1', {
        'requesterId': 'user-1',
        'requesterName': 'Maria',
        'requesterBarangay': 'San Isidro',
        'kind': 'special',
        'title': 'Bulky waste pickup',
        'description': 'Old furniture from the barangay hall.',
        'category': 'recyclable',
        'estimatedQuantity': '2 truckloads',
        'location': 'Barangay hall',
        'preferredDate': Timestamp.fromDate(DateTime(2026, 12, 1)),
        'status': 'assigned',
        'assignedDriverId': 'driver-1',
        'assignedDriverName': 'Jose',
        'history': [
          {'status': 'pending', 'byName': 'Maria', 'note': 'Request submitted'},
          {'status': 'assigned', 'byName': 'Staff', 'note': 'Assigned to Jose'},
        ],
      });

      expect(request.isSpecial, isTrue);
      expect(request.status, RequestStatus.assigned);
      expect(request.status.isOpen, isTrue);
      expect(request.assignedDriverName, 'Jose');
      expect(request.history.length, 2);
      expect(request.history.last.status, RequestStatus.assigned);
    });

    test('rejected and completed requests are closed', () {
      expect(RequestStatus.rejected.isOpen, isFalse);
      expect(RequestStatus.completed.isOpen, isFalse);
      expect(RequestStatus.pending.isOpen, isTrue);
      expect(RequestStatusX.fromName('unknown'), RequestStatus.pending);
    });
  });

  group('announcements and events', () {
    test('an announcement is live only when published and due', () {
      final published = Announcement.fromDoc('a1', {
        'title': 'Collection schedule',
        'body': 'Please segregate.',
        'category': 'schedule',
        'status': 'published',
        'publishAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1)),
        ),
      });
      expect(published.isLive, isTrue);
      expect(published.category, AnnouncementCategory.schedule);

      final draft = Announcement.fromDoc('a2', {
        'title': 'Draft',
        'body': 'Not yet.',
        'status': 'draft',
      });
      expect(draft.isLive, isFalse);
    });

    test('an event is completed after its end time', () {
      final past = CommunityEvent.fromDoc('e1', {
        'title': 'Clean-up',
        'description': 'Done',
        'startAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 2)),
        ),
        'endAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 2, hours: -2)),
        ),
        'status': 'published',
      });
      expect(past.isCompleted, isTrue);
      expect(past.isUpcoming, isFalse);
    });
  });

  group('driver location state', () {
    test('maps device states without blaming the driver', () {
      expect(DriverLocationStateX.fromWire('disabled'),
          DriverLocationState.disabled);
      expect(DriverLocationStateX.fromWire('permission'),
          DriverLocationState.permission);
      expect(DriverLocationStateX.fromWire('offline'),
          DriverLocationState.offline);
      expect(DriverLocationStateX.fromWire('nonsense'),
          DriverLocationState.unknown);
      expect(DriverLocationState.ok.needsAttention, isFalse);
      expect(DriverLocationState.disabled.needsAttention, isTrue);
      expect(DriverLocationState.offline.staffMessage, isNotEmpty);
    });
  });

  group('collection points', () {
    test('summarises schedules and coordinates', () {
      final point = CollectionPoint.fromDoc('p1', {
        'name': 'Purok 3 court',
        'address': 'Purok 3',
        'lat': 14.6,
        'lng': 121.0,
        'scheduleDays': ['Mon', 'Thu'],
        'scheduleTime': '07:00',
        'status': 'active',
      });
      expect(point.scheduleLabel, 'Mon, Thu · 07:00');
      expect(point.isActive, isTrue);
      expect(point.latLng.latitude, 14.6);

      final empty = CollectionPoint.fromDoc('p2', {
        'name': 'No schedule',
        'address': 'Somewhere',
        'lat': 14.6,
        'lng': 121.0,
      });
      expect(empty.scheduleLabel, 'No schedule set');
    });
  });

  group('city hall desk', () {
    test('only tickets waiting on City Hall reach the signature queue', () {
      final documents = buildCityHallDocuments(
        tickets: [
          _ticket(id: 't1', status: TicketStatus.iswimSigned),
          _ticket(id: 't2', status: TicketStatus.barangaySigned),
          _ticket(id: 't3', status: TicketStatus.issued),
          _ticket(id: 't4', status: TicketStatus.completed),
        ],
        memos: const [],
      );

      expect(documents.pendingSignatures, 1);
      final awaiting = documents.forSignature
          .where((d) => d.status == DeskDocumentStatus.awaitingSignature)
          .single;
      expect(awaiting.canSign, isTrue);
      expect(awaiting.category, DeskCategory.driver);
      // The completed ticket is kept as signed history and as a received item.
      expect(
        documents.forSignature
            .where((d) => d.status == DeskDocumentStatus.signed)
            .length,
        1,
      );
      expect(documents.received.single.status, DeskDocumentStatus.completed);
    });

    test('resolves the driver full name from the live directory', () {
      final documents = buildCityHallDocuments(
        tickets: [
          _ticket(
            id: 't1',
            status: TicketStatus.iswimSigned,
            driverId: 'driver-9',
            driverName: 'R. Dela Cruz',
            code: 'TT-2026-0042',
          ),
        ],
        memos: const [],
        people: const {
          'driver-9': DeskPerson(
            uid: 'driver-9',
            name: 'Ramon Dela Cruz',
            role: 'driver',
          ),
        },
      );

      final document = documents.forSignature.single;
      expect(document.senderName, 'Ramon Dela Cruz');
      expect(document.displayReference, 'TT-2026-0042');
      expect(document.truck, 'ABC 1234');
      expect(document.matchesSearch('ramon'), isTrue);
      expect(document.matchesSearch('tt-2026'), isTrue);
      expect(document.matchesSearch('abc 1234'), isTrue);
      expect(document.matchesSearch('nobody'), isFalse);
    });

    test('category, status and search combine', () {
      final documents = buildCityHallDocuments(
        tickets: [
          _ticket(
            id: 't1',
            status: TicketStatus.iswimSigned,
            driverName: 'Ramon Dela Cruz',
          ),
          _ticket(
            id: 't2',
            status: TicketStatus.iswimSigned,
            driverId: 'd2',
            driverName: 'Jose Santos',
            code: 'TT-2026-0002',
          ),
        ],
        memos: [
          _memo(id: 'm1', status: MemoStatus.sent, subject: 'Route adjustment'),
        ],
      );

      final awaiting = documents.forSignature
          .where((d) => d.matchesSignatureFilter(SignatureFilter.awaiting))
          .toList();
      expect(awaiting.length, 3);

      expect(
        awaiting
            .where((d) =>
                d.matchesCategory(DeskCategory.driver) &&
                d.matchesSearch('ramon'))
            .length,
        1,
      );
      expect(
        awaiting
            .where((d) =>
                d.matchesCategory(DeskCategory.iswim) &&
                d.matchesSearch('ramon'))
            .length,
        0,
      );
      expect(
        awaiting
            .where((d) =>
                d.matchesCategory(DeskCategory.iswim) &&
                d.matchesSearch('route'))
            .length,
        1,
      );
    });

    test('memos to City Hall are signed, then acknowledged', () {
      final pending = buildCityHallDocuments(
        tickets: const [],
        memos: [
          _memo(id: 'm1', status: MemoStatus.sent, fromRole: 'barangay'),
        ],
      );

      expect(pending.forSignature.single.category, DeskCategory.barangay);
      expect(pending.forSignature.single.canSign, isTrue);
      expect(pending.received.single.status, DeskDocumentStatus.newDocument);

      final signed = buildCityHallDocuments(
        tickets: const [],
        memos: [_memo(id: 'm2', status: MemoStatus.acknowledged)],
      );

      expect(signed.forSignature.single.status, DeskDocumentStatus.signed);
      expect(signed.forSignature.single.canSign, isFalse);
      expect(signed.received.single.status, DeskDocumentStatus.acknowledged);
      expect(signed.pendingSignatures, 0);
    });

    test('a memo addressed elsewhere never reaches the City Hall desk', () {
      final documents = buildCityHallDocuments(
        tickets: const [],
        memos: [
          _memo(id: 'm1', status: MemoStatus.sent, toChannel: 'iswim'),
          _memo(id: 'm2', status: MemoStatus.sent, toChannel: 'barangay'),
        ],
      );

      expect(documents.forSignature, isEmpty);
      expect(documents.received, isEmpty);
    });

    test('rejected and returned tickets are kept for the record', () {
      final documents = buildCityHallDocuments(
        tickets: [
          _ticket(id: 't1', status: TicketStatus.rejected),
          _ticket(id: 't2', status: TicketStatus.revisionRequired),
        ],
        memos: const [],
      );

      expect(documents.pendingSignatures, 0);
      expect(
        documents.forSignature
            .where((d) => d.status == DeskDocumentStatus.rejected)
            .length,
        1,
      );
      expect(
        documents.forSignature
            .where((d) => d.status == DeskDocumentStatus.returnedForRevision)
            .length,
        1,
      );
    });
  });
}

TripTicket _ticket({
  required String id,
  required TicketStatus status,
  String driverId = 'driver-1',
  String driverName = 'Ramon Dela Cruz',
  String code = 'TT-2026-0001',
}) {
  return TripTicket(
    id: id,
    code: code,
    wave: 1,
    truckId: 'truck-1',
    plateNumber: 'ABC 1234',
    wheelers: 4,
    driverId: driverId,
    driverName: driverName,
    route: 'Purok 1 – Purok 4',
    zone: 'Zone 3',
    date: '2026-11-14',
    windowStart: '07:00',
    windowEnd: '09:00',
    notes: '',
    status: status,
    createdBy: 'iswim-1',
    createdAt: DateTime(2026, 11, 14, 6),
    submittedAt: DateTime(2026, 11, 14, 8),
    completedAt: status == TicketStatus.completed
        ? DateTime(2026, 11, 14, 11)
        : null,
  );
}

Memo _memo({
  required String id,
  required MemoStatus status,
  String toChannel = 'cityHall',
  String fromRole = 'iswim',
  String subject = 'Route adjustment',
}) {
  return Memo(
    id: id,
    kind: MemoKind.memo,
    subject: subject,
    body: 'Please review the attached route.',
    fromName: 'Desk Officer',
    fromRole: fromRole,
    fromUid: 'user-$id',
    toChannel: toChannel,
    status: status,
    createdAt: DateTime(2026, 11, 14, 8),
    receivedAt:
        status == MemoStatus.sent ? null : DateTime(2026, 11, 14, 9),
    acknowledgedAt: status == MemoStatus.acknowledged
        ? DateTime(2026, 11, 14, 10)
        : null,
  );
}
