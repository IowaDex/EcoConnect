import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

/// Complaints are deliberately separate from Wave 1 requests, Wave 2 reports
/// and special collection requests: they go straight to DSQC / City Hall and
/// never enter the barangay collection queue.
enum ComplaintCategory {
  missedCollection,
  illegalDumping,
  overflowingBin,
  truckConduct,
  schedule,
  other,
}

extension ComplaintCategoryX on ComplaintCategory {
  String get label => switch (this) {
        ComplaintCategory.missedCollection => 'Missed collection',
        ComplaintCategory.illegalDumping => 'Illegal dumping',
        ComplaintCategory.overflowingBin => 'Overflowing bin',
        ComplaintCategory.truckConduct => 'Truck crew conduct',
        ComplaintCategory.schedule => 'Collection schedule',
        ComplaintCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ComplaintCategory.missedCollection => Icons.local_shipping_outlined,
        ComplaintCategory.illegalDumping => Icons.delete_outline_rounded,
        ComplaintCategory.overflowingBin => Icons.delete_sweep_outlined,
        ComplaintCategory.truckConduct => Icons.person_off_outlined,
        ComplaintCategory.schedule => Icons.event_busy_outlined,
        ComplaintCategory.other => Icons.report_outlined,
      };

  static ComplaintCategory fromName(String? name) => ComplaintCategory.values
      .firstWhere((c) => c.name == name, orElse: () => ComplaintCategory.other);
}

enum ComplaintStatus { pending, underReview, resolved, rejected }

extension ComplaintStatusX on ComplaintStatus {
  String get label => switch (this) {
        ComplaintStatus.pending => 'Received',
        ComplaintStatus.underReview => 'Under review',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        ComplaintStatus.pending => AppColors.warning,
        ComplaintStatus.underReview => const Color(0xFF1565C0),
        ComplaintStatus.resolved => AppColors.primary,
        ComplaintStatus.rejected => AppColors.error,
      };

  bool get isOpen =>
      this == ComplaintStatus.pending || this == ComplaintStatus.underReview;

  static ComplaintStatus fromName(String? name) => ComplaintStatus.values
      .firstWhere((s) => s.name == name, orElse: () => ComplaintStatus.pending);
}

DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// One message in the complaint thread. City Hall replies, the resident reads.
class ComplaintResponse {
  const ComplaintResponse({
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

  static ComplaintResponse? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    return ComplaintResponse(
      message: raw['message'] as String? ?? '',
      byName: raw['byName'] as String? ?? 'City Hall',
      byRole: raw['byRole'] as String? ?? 'cityHall',
      at: _date(raw['at']),
    );
  }
}

/// A complaint submitted directly to DSQC / City Hall.
class Complaint {
  const Complaint({
    required this.id,
    required this.referenceNo,
    required this.residentId,
    required this.residentName,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    this.residentBarangay,
    this.location,
    this.images = const [],
    this.responses = const [],
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  final String id;
  final String referenceNo;
  final String residentId;
  final String residentName;
  final String? residentBarangay;
  final String title;
  final String description;
  final ComplaintCategory category;
  final ComplaintStatus status;
  final String? location;
  final List<UploadPayload> images;
  final List<ComplaintResponse> responses;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  static Complaint? fromDoc(String id, Map<String, dynamic> data) {
    if (data['title'] is! String) return null;
    final rawImages = data['images'];
    final rawResponses = data['responses'];
    return Complaint(
      id: id,
      referenceNo: data['referenceNo'] as String? ?? id,
      residentId: data['residentId'] as String? ?? '',
      residentName: data['residentName'] as String? ?? 'Resident',
      residentBarangay: data['residentBarangay'] as String?,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      category: ComplaintCategoryX.fromName(data['category'] as String?),
      status: ComplaintStatusX.fromName(data['status'] as String?),
      location: data['location'] as String?,
      images: rawImages is List
          ? rawImages
              .map(UploadPayload.fromMap)
              .whereType<UploadPayload>()
              .toList(growable: false)
          : const [],
      responses: rawResponses is List
          ? rawResponses
              .map(ComplaintResponse.fromMap)
              .whereType<ComplaintResponse>()
              .toList(growable: false)
          : const [],
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      resolvedAt: _date(data['resolvedAt']),
    );
  }
}
