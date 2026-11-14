import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

/// What a manual covers. Kept small so the list can be filtered by hand
/// without a composite index.
enum ManualCategory { collection, operations, safety, other }

extension ManualCategoryX on ManualCategory {
  String get label => switch (this) {
        ManualCategory.collection => 'Collection procedure',
        ManualCategory.operations => 'Operations',
        ManualCategory.safety => 'Safety',
        ManualCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ManualCategory.collection => Icons.route_rounded,
        ManualCategory.operations => Icons.settings_outlined,
        ManualCategory.safety => Icons.health_and_safety_outlined,
        ManualCategory.other => Icons.menu_book_outlined,
      };

  static ManualCategory fromName(String? name) => ManualCategory.values
      .firstWhere((c) => c.name == name, orElse: () => ManualCategory.other);
}

/// Draft is only used while Iswim is writing; publishing a version moves the
/// manual to [submitted] and City Hall acknowledging it moves it to
/// [acknowledged]. Any later version resets it to [submitted].
enum ManualStatus { draft, submitted, acknowledged }

extension ManualStatusX on ManualStatus {
  String get label => switch (this) {
        ManualStatus.draft => 'Draft',
        ManualStatus.submitted => 'Sent to City Hall',
        ManualStatus.acknowledged => 'Received by City Hall',
      };

  Color get color => switch (this) {
        ManualStatus.draft => AppColors.inkMuted,
        ManualStatus.submitted => AppColors.warning,
        ManualStatus.acknowledged => AppColors.primary,
      };

  static ManualStatus fromName(String? name) => ManualStatus.values
      .firstWhere((s) => s.name == name, orElse: () => ManualStatus.draft);
}

DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// One uploaded revision of a manual.
class ManualVersion {
  const ManualVersion({
    required this.id,
    required this.version,
    required this.notes,
    required this.submittedBy,
    required this.submittedByName,
    this.file,
    this.submittedAt,
  });

  final String id;
  final int version;
  final String notes;
  final String submittedBy;
  final String submittedByName;
  final UploadPayload? file;
  final DateTime? submittedAt;

  static ManualVersion? fromDoc(String id, Map<String, dynamic> data) {
    return ManualVersion(
      id: id,
      version: (data['version'] as num?)?.toInt() ?? 1,
      notes: data['notes'] as String? ?? '',
      submittedBy: data['submittedBy'] as String? ?? '',
      submittedByName: data['submittedByName'] as String? ?? 'Iswim',
      file: UploadPayload.fromMap(data['file']),
      submittedAt: _date(data['submittedAt']),
    );
  }
}

/// A controlled manual. The current revision is denormalised onto the parent
/// document so the list does not need one read per manual, while the complete
/// history lives in `manuals/{id}/versions`.
class Manual {
  const Manual({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.version,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.currentNotes = '',
    this.file,
    this.createdAt,
    this.updatedAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
  });

  final String id;
  final String title;
  final ManualCategory category;
  final String summary;
  final int version;
  final ManualStatus status;
  final String createdBy;
  final String createdByName;
  final String currentNotes;
  final UploadPayload? file;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;

  bool get hasFile => file != null;

  static Manual? fromDoc(String id, Map<String, dynamic> data) {
    if (data['title'] is! String) return null;
    return Manual(
      id: id,
      title: data['title'] as String,
      category: ManualCategoryX.fromName(data['category'] as String?),
      summary: data['summary'] as String? ?? '',
      version: (data['version'] as num?)?.toInt() ?? 1,
      status: ManualStatusX.fromName(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Iswim',
      currentNotes: data['currentNotes'] as String? ?? '',
      file: UploadPayload.fromMap(data['file']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      acknowledgedAt: _date(data['acknowledgedAt']),
      acknowledgedByName: data['acknowledgedByName'] as String?,
    );
  }
}

enum ManualRequestStatus { pending, fulfilled, cancelled }

extension ManualRequestStatusX on ManualRequestStatus {
  String get label => switch (this) {
        ManualRequestStatus.pending => 'Waiting for Iswim',
        ManualRequestStatus.fulfilled => 'Submitted to City Hall',
        ManualRequestStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        ManualRequestStatus.pending => AppColors.warning,
        ManualRequestStatus.fulfilled => AppColors.primary,
        ManualRequestStatus.cancelled => AppColors.inkMuted,
      };

  static ManualRequestStatus fromName(String? name) =>
      ManualRequestStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ManualRequestStatus.pending,
      );
}

/// City Hall asking Iswim for a specific manual.
class ManualRequest {
  const ManualRequest({
    required this.id,
    required this.code,
    required this.title,
    required this.details,
    required this.requestedByName,
    required this.status,
    this.neededBy,
    this.createdAt,
    this.fulfilledAt,
    this.fulfilledByName,
    this.manualId,
  });

  final String id;
  final String code;
  final String title;
  final String details;
  final String requestedByName;
  final ManualRequestStatus status;
  final DateTime? neededBy;
  final DateTime? createdAt;
  final DateTime? fulfilledAt;
  final String? fulfilledByName;
  final String? manualId;

  static ManualRequest? fromDoc(String id, Map<String, dynamic> data) {
    if (data['title'] is! String) return null;
    return ManualRequest(
      id: id,
      code: data['code'] as String? ?? id,
      title: data['title'] as String,
      details: data['details'] as String? ?? '',
      requestedByName: data['requestedByName'] as String? ?? 'City Hall',
      status: ManualRequestStatusX.fromName(data['status'] as String?),
      neededBy: _date(data['neededBy']),
      createdAt: _date(data['createdAt']),
      fulfilledAt: _date(data['fulfilledAt']),
      fulfilledByName: data['fulfilledByName'] as String?,
      manualId: data['manualId'] as String?,
    );
  }
}
