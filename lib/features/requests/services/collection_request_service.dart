import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_request.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

class CollectionRequestService {
  static final CollectionRequestService _instance =
      CollectionRequestService._internal();
  factory CollectionRequestService() => _instance;
  CollectionRequestService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('collectionRequests');

  Stream<List<CollectionRequest>> watchMine(String userId) {
    return _col
        .where('requesterId', isEqualTo: userId)
        .snapshots()
        .map(_sorted);
  }

  Stream<List<CollectionRequest>> watchForDriver(String driverId) {
    return _col
        .where('assignedDriverId', isEqualTo: driverId)
        .snapshots()
        .map(_sorted);
  }

  Stream<List<CollectionRequest>> watchAll() => _col.snapshots().map(_sorted);

  List<CollectionRequest> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final items = snap.docs
        .map((doc) => CollectionRequest.fromDoc(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    return items;
  }

  /// Submits a request. [kind] must be special only for verified government
  /// personnel; the Firestore rules enforce the same check server-side.
  Future<String> create({
    required String requesterId,
    required String requesterName,
    String? requesterPhone,
    String? requesterBarangay,
    required RequestKind kind,
    required String title,
    required String description,
    required WasteCategory category,
    required String estimatedQuantity,
    required String location,
    required DateTime preferredDate,
    String? remarks,
    List<UploadPayload> images = const [],
  }) async {
    final ref = _col.doc();
    await ref.set({
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhone': requesterPhone,
      'requesterBarangay': requesterBarangay,
      'kind': kind.name,
      'title': title.trim(),
      'description': description.trim(),
      'category': category.name,
      'estimatedQuantity': estimatedQuantity.trim(),
      'location': location.trim(),
      'preferredDate': Timestamp.fromDate(preferredDate),
      'remarks': remarks?.trim(),
      'images': images.map((image) => image.toMap()).toList(),
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': [
        {
          'status': RequestStatus.pending.name,
          // FieldValue.serverTimestamp() is rejected inside an array, so the
          // audit trail uses a client timestamp while the document itself
          // still gets server timestamps on createdAt/updatedAt.
          'at': Timestamp.now(),
          'byName': requesterName,
          'note': 'Request submitted',
        },
      ],
    });

    await _notifications.notifyStaff(
      title: kind == RequestKind.special
          ? 'New special collection request'
          : 'New collection request',
      body: '$requesterName submitted "${title.trim()}".',
      type: AppNotificationType.request,
      data: {'requestId': ref.id},
    );

    return ref.id;
  }

  Future<void> updateStatus({
    required CollectionRequest request,
    required RequestStatus status,
    required String actorId,
    required String actorName,
    String? note,
    String? rejectionReason,
  }) async {
    final history = [
      ..._historyOf(request),
      {
        'status': status.name,
        'at': Timestamp.now(),
        'byName': actorName,
        'note': note,
      },
    ];

    await _col.doc(request.id).update({
      'status': status.name,
      'staffNote': note,
      'rejectionReason': rejectionReason,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': history,
    });

    await _notifications.push(
      userId: request.requesterId,
      title: _statusTitle(status),
      body: note?.trim().isNotEmpty == true
          ? note!.trim()
          : 'Your request "${request.title}" is now ${status.label.toLowerCase()}.',
      type: AppNotificationType.request,
      data: {'requestId': request.id},
    );
  }

  Future<void> assignDriver({
    required CollectionRequest request,
    required String driverId,
    required String driverName,
    required DateTime scheduledAt,
    required String actorId,
    required String actorName,
  }) async {
    final history = [
      ..._historyOf(request),
      {
        'status': RequestStatus.assigned.name,
        'at': Timestamp.now(),
        'byName': actorName,
        'note': 'Assigned to $driverName',
      },
    ];

    await _col.doc(request.id).update({
      'status': RequestStatus.assigned.name,
      'assignedDriverId': driverId,
      'assignedDriverName': driverName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': history,
    });

    await _notifications.push(
      userId: request.requesterId,
      title: 'Collection scheduled',
      body:
          '$driverName will collect your ${request.category.shortLabel.toLowerCase()} waste on ${scheduledAt.month}/${scheduledAt.day}.',
      type: AppNotificationType.request,
      data: {'requestId': request.id},
    );
    await _notifications.push(
      userId: driverId,
      title: 'New collection assignment',
      body:
          '${request.title} · ${request.location}. Scheduled ${scheduledAt.month}/${scheduledAt.day}.',
      type: AppNotificationType.route,
      data: {'requestId': request.id},
    );
  }

  /// Barangay reviews the request, then passes it up as wave 2.
  Future<void> passToCityHall(String id, {String? byName}) async {
    await _col.doc(id).update({
      'wave': 2,
      'cityHallStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
      if (byName != null) 'staffNote': 'Passed to City Hall by $byName',
    });
    await _notifications.notifyCityHall(
      title: 'Wave 2 request for approval',
      body: 'The barangay passed a collection request to City Hall.',
      type: AppNotificationType.request,
      data: {'requestId': id, 'kind': 'wave2Pending'},
    );
  }

  /// City Hall approves or rejects the wave 2 request. The resident and the
  /// barangay both see the outcome on the request thread.
  Future<void> cityHallDecision(
    String id, {
    required bool approve,
    String? note,
  }) async {
    await _col.doc(id).update({
      'cityHallStatus': approve ? 'approved' : 'rejected',
      'status': approve
          ? RequestStatus.approved.name
          : RequestStatus.rejected.name,
      'rejectionReason': approve ? null : note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _notifications.notifyStaff(
      title: approve ? 'Wave 2 approved by City Hall' : 'Wave 2 rejected',
      body: note ?? (approve
          ? 'City Hall approved the request. The barangay can schedule it.'
          : 'City Hall rejected the request.'),
      type: AppNotificationType.request,
      data: {'requestId': id, 'kind': 'wave2Decision'},
    );

    // The resident who filed the request gets the final decision directly.
    final snap = await _col.doc(id).get();
    final requesterId = snap.data()?['requesterId'] as String?;
    if (requesterId != null && requesterId.isNotEmpty) {
      await _notifications.push(
        userId: requesterId,
        title: approve ? 'Wave 2 request approved' : 'Wave 2 request rejected',
        body: note?.trim().isNotEmpty == true
            ? note!.trim()
            : approve
                ? 'City Hall approved your request. The barangay will schedule it.'
                : 'City Hall rejected your request.',
        type: AppNotificationType.request,
        data: {'requestId': id, 'kind': 'wave2Decision'},
      );
    }
  }

  /// City Hall replies on the request thread. The reply is stored on the
  /// request itself, so the resident and the concerned barangay read the same
  /// conversation; both are notified.
  Future<void> addCityHallResponse({
    required CollectionRequest request,
    required String message,
    required String byName,
  }) async {
    final reply = RequestResponse(
      message: message.trim(),
      byName: byName,
      byRole: 'cityHall',
    );

    await _col.doc(request.id).update({
      'responses': FieldValue.arrayUnion([reply.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.push(
      userId: request.requesterId,
      title: 'City Hall replied to your request',
      body: message.trim(),
      type: AppNotificationType.request,
      data: {'requestId': request.id, 'kind': 'cityHallResponse'},
    );
    await _notifications.notifyStaff(
      title: 'City Hall reply · ${request.title}',
      body: '$byName: ${message.trim()}',
      type: AppNotificationType.request,
      data: {
        'requestId': request.id,
        'kind': 'cityHallResponse',
        'requesterId': request.requesterId,
      },
    );
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Lets the assigned driver move their own job forward: assigned ->
  /// inProgress -> collected. Staff keep full control of every other status.
  Future<void> driverAdvance({
    required CollectionRequest request,
    required RequestStatus status,
    required String driverName,
  }) async {
    await _col.doc(request.id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': [
        ..._historyOf(request),
        {
          'status': status.name,
          'at': Timestamp.now(),
          'byName': driverName,
          'note': status == RequestStatus.inProgress
              ? 'Driver is on the way'
              : 'Waste collected',
        },
      ],
    });

    await _notifications.push(
      userId: request.requesterId,
      title: _statusTitle(status),
      body: status == RequestStatus.inProgress
          ? '$driverName is on the way to ${request.location}.'
          : '$driverName collected the waste for "${request.title}".',
      type: AppNotificationType.request,
      data: {'requestId': request.id},
    );
  }

  /// Converts the stored audit trail back to plain maps. FieldValue values
  /// cannot be nested in a list, so timestamps are copied as-is.
  List<Map<String, dynamic>> _historyOf(CollectionRequest request) {
    return [
      for (final entry in request.history)
        {
          'status': entry.status.name,
          'at': entry.at == null ? null : Timestamp.fromDate(entry.at!),
          'byName': entry.byName,
          'note': entry.note,
        },
    ];
  }

  String _statusTitle(RequestStatus status) => switch (status) {
        RequestStatus.approved => 'Request approved',
        RequestStatus.rejected => 'Request rejected',
        RequestStatus.assigned => 'Collection scheduled',
        RequestStatus.inProgress => 'Collector on the way',
        RequestStatus.collected => 'Waste collected',
        RequestStatus.completed => 'Request completed',
        RequestStatus.underReview => 'Request under review',
        RequestStatus.pending => 'Request received',
      };
}
