import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

/// Regular resident request vs. the government-personnel-only request type.
enum RequestKind { resident, special }

extension RequestKindX on RequestKind {
  String get label => this == RequestKind.special
      ? 'Special collection'
      : 'Residential collection';

  static RequestKind fromName(String? name) =>
      name == 'special' ? RequestKind.special : RequestKind.resident;
}

enum RequestStatus {
  pending,
  underReview,
  approved,
  assigned,
  inProgress,
  collected,
  completed,
  rejected,
}

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.underReview => 'Under review',
        RequestStatus.approved => 'Approved',
        RequestStatus.assigned => 'Assigned',
        RequestStatus.inProgress => 'In progress',
        RequestStatus.collected => 'Collected',
        RequestStatus.completed => 'Completed',
        RequestStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        RequestStatus.pending => AppColors.warning,
        RequestStatus.underReview => const Color(0xFF1565C0),
        RequestStatus.approved => AppColors.primary,
        RequestStatus.assigned => const Color(0xFF6A1B9A),
        RequestStatus.inProgress => const Color(0xFFEF6C00),
        RequestStatus.collected => const Color(0xFF00897B),
        RequestStatus.completed => AppColors.darkGreen,
        RequestStatus.rejected => AppColors.error,
      };

  IconData get icon => switch (this) {
        RequestStatus.pending => Icons.hourglass_empty_rounded,
        RequestStatus.underReview => Icons.search_rounded,
        RequestStatus.approved => Icons.check_rounded,
        RequestStatus.assigned => Icons.person_pin_circle_outlined,
        RequestStatus.inProgress => Icons.local_shipping_rounded,
        RequestStatus.collected => Icons.inventory_2_outlined,
        RequestStatus.completed => Icons.task_alt_rounded,
        RequestStatus.rejected => Icons.close_rounded,
      };

  bool get isOpen => this != RequestStatus.completed &&
      this != RequestStatus.rejected;

  bool get isTerminal => !isOpen;

  static RequestStatus fromName(String? name) => RequestStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RequestStatus.pending,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// One line in the request audit trail.
class RequestHistoryEntry {
  const RequestHistoryEntry({
    required this.status,
    this.at,
    this.byName,
    this.note,
  });

  final RequestStatus status;
  final DateTime? at;
  final String? byName;
  final String? note;

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'at': FieldValue.serverTimestamp(),
        'byName': byName,
        'note': note,
      };

  static RequestHistoryEntry fromMap(dynamic raw) {
    if (raw is! Map) {
      return const RequestHistoryEntry(status: RequestStatus.pending);
    }
    return RequestHistoryEntry(
      status: RequestStatusX.fromName(raw['status'] as String?),
      at: _asDate(raw['at']),
      byName: raw['byName'] as String?,
      note: raw['note'] as String?,
    );
  }
}

/// One message in the shared response thread. City Hall replies are visible to
/// the requesting resident **and** the concerned barangay staff.
class RequestResponse {
  const RequestResponse({
    required this.message,
    required this.byName,
    required this.byRole,
    this.at,
  });

  final String message;
  final String byName;
  final String byRole;
  final DateTime? at;

  Map<String, dynamic> toMap() => {
        'message': message,
        'byName': byName,
        'byRole': byRole,
        'at': Timestamp.now(),
      };

  static RequestResponse? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    return RequestResponse(
      message: raw['message'] as String? ?? '',
      byName: raw['byName'] as String? ?? 'City Hall',
      byRole: raw['byRole'] as String? ?? 'cityHall',
      at: _asDate(raw['at']),
    );
  }
}

/// A garbage collection request submitted by a resident or government
/// personnel. Stored at collectionRequests/{id}.
class CollectionRequest {
  const CollectionRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.kind,
    required this.title,
    required this.description,
    required this.category,
    required this.estimatedQuantity,
    required this.location,
    required this.preferredDate,
    this.requesterPhone,
    this.requesterBarangay,
    this.remarks,
    this.images = const [],
    this.status = RequestStatus.pending,
    this.assignedDriverId,
    this.assignedDriverName,
    this.scheduledAt,
    this.staffNote,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.history = const [],
    this.responses = const [],
    this.wave = 1,
    this.cityHallStatus = 'none',
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterPhone;
  final String? requesterBarangay;
  final RequestKind kind;
  final String title;
  final String description;
  final WasteCategory category;
  final String estimatedQuantity;
  final String location;
  final DateTime preferredDate;
  final String? remarks;
  final List<UploadPayload> images;
  final RequestStatus status;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final DateTime? scheduledAt;
  final String? staffNote;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RequestHistoryEntry> history;
  final List<RequestResponse> responses;

  /// 1 for the regular round, 2 once the barangay passes it to City Hall.
  final int wave;

  /// Wave 2 approval state: `none`, `pending`, `approved` or `rejected`.
  final String cityHallStatus;

  bool get needsCityHall => cityHallStatus == 'pending';
  bool get isWave2 => wave == 2;

  bool get isSpecial => kind == RequestKind.special;

  bool get isAssigned => assignedDriverId != null;

  CollectionRequest copyWith({
    RequestStatus? status,
    String? assignedDriverId,
    String? assignedDriverName,
    DateTime? scheduledAt,
    String? staffNote,
    String? rejectionReason,
  }) {
    return CollectionRequest(
      id: id,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterPhone: requesterPhone,
      requesterBarangay: requesterBarangay,
      kind: kind,
      title: title,
      description: description,
      category: category,
      estimatedQuantity: estimatedQuantity,
      location: location,
      preferredDate: preferredDate,
      remarks: remarks,
      images: images,
      status: status ?? this.status,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      staffNote: staffNote ?? this.staffNote,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      history: history,
      responses: responses,
      wave: wave,
      cityHallStatus: cityHallStatus,
    );
  }

  static CollectionRequest fromDoc(String id, Map<String, dynamic> data) {
    final rawImages = data['images'];
    final rawHistory = data['history'];
    final rawResponses = data['responses'];
    return CollectionRequest(
      id: id,
      requesterId: (data['requesterId'] as String?) ?? '',
      requesterName: (data['requesterName'] as String?) ?? 'Resident',
      requesterPhone: data['requesterPhone'] as String?,
      requesterBarangay: data['requesterBarangay'] as String?,
      kind: RequestKindX.fromName(data['kind'] as String?),
      title: (data['title'] as String?) ?? 'Collection request',
      description: (data['description'] as String?) ?? '',
      category: WasteCategoryX.fromName(data['category'] as String?),
      estimatedQuantity: (data['estimatedQuantity'] as String?) ?? '—',
      location: (data['location'] as String?) ?? '—',
      preferredDate: _asDate(data['preferredDate']) ?? DateTime.now(),
      remarks: data['remarks'] as String?,
      images: rawImages is List
          ? rawImages
              .map(UploadPayload.fromMap)
              .whereType<UploadPayload>()
              .toList(growable: false)
          : const [],
      status: RequestStatusX.fromName(data['status'] as String?),
      wave: (data['wave'] as num?)?.toInt() ?? 1,
      cityHallStatus: data['cityHallStatus'] as String? ?? 'none',
      assignedDriverId: data['assignedDriverId'] as String?,
      assignedDriverName: data['assignedDriverName'] as String?,
      scheduledAt: _asDate(data['scheduledAt']),
      staffNote: data['staffNote'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
      history: rawHistory is List
          ? rawHistory
              .map(RequestHistoryEntry.fromMap)
              .toList(growable: false)
          : const [],
      responses: rawResponses is List
          ? rawResponses
              .map(RequestResponse.fromMap)
              .whereType<RequestResponse>()
              .toList(growable: false)
          : const [],
    );
  }
}
