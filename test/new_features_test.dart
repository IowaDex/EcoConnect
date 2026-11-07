import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/models/waste_category.dart';
import 'package:eco_connect/core/utils/image_payload.dart';
import 'package:eco_connect/features/announcements/models/announcement.dart';
import 'package:eco_connect/features/collection_points/models/collection_point.dart';
import 'package:eco_connect/features/driver/services/driver_session_service.dart';
import 'package:eco_connect/features/events/models/community_event.dart';
import 'package:eco_connect/features/requests/models/collection_request.dart';
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
}
