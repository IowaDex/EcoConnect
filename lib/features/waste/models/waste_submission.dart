import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

enum WasteStatus { pending, approved, rejected, scheduled, collected }

extension WasteStatusX on WasteStatus {
  String get label => switch (this) {
        WasteStatus.pending => 'Pending validation',
        WasteStatus.approved => 'Approved',
        WasteStatus.rejected => 'Rejected',
        WasteStatus.scheduled => 'Scheduled for collection',
        WasteStatus.collected => 'Collected',
      };

  Color get color => switch (this) {
        WasteStatus.pending => AppColors.warning,
        WasteStatus.approved => AppColors.primary,
        WasteStatus.rejected => AppColors.error,
        WasteStatus.scheduled => const Color(0xFF6A1B9A),
        WasteStatus.collected => const Color(0xFF00897B),
      };

  IconData get icon => switch (this) {
        WasteStatus.pending => Icons.hourglass_empty_rounded,
        WasteStatus.approved => Icons.verified_rounded,
        WasteStatus.rejected => Icons.cancel_outlined,
        WasteStatus.scheduled => Icons.event_available_rounded,
        WasteStatus.collected => Icons.inventory_2_rounded,
      };

  static WasteStatus fromName(String? name) => WasteStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => WasteStatus.pending,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A photo submission of household waste awaiting barangay validation.
class WasteSubmission {
  const WasteSubmission({
    required this.id,
    required this.userId,
    required this.userName,
    required this.description,
    required this.category,
    required this.quantity,
    required this.location,
    this.barangay,
    this.images = const [],
    this.status = WasteStatus.pending,
    this.remarks,
    this.validatedBy,
    this.validatedAt,
    this.pointsAwarded = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String description;
  final WasteCategory category;
  final String quantity;
  final String location;
  final String? barangay;
  final List<UploadPayload> images;
  final WasteStatus status;
  final String? remarks;
  final String? validatedBy;
  final DateTime? validatedAt;
  final int pointsAwarded;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get coverUrl => images.isEmpty ? '' : images.first.dataUrl;

  static WasteSubmission fromDoc(String id, Map<String, dynamic> data) {
    final rawImages = data['images'];
    return WasteSubmission(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? 'Resident',
      description: (data['description'] as String?) ?? '',
      category: WasteCategoryX.fromName(data['category'] as String?),
      quantity: (data['quantity'] as String?) ?? '—',
      location: (data['location'] as String?) ?? '—',
      barangay: data['barangay'] as String?,
      images: rawImages is List
          ? rawImages
              .map(UploadPayload.fromMap)
              .whereType<UploadPayload>()
              .toList(growable: false)
          : const [],
      status: WasteStatusX.fromName(data['status'] as String?),
      remarks: data['remarks'] as String?,
      validatedBy: data['validatedBy'] as String?,
      validatedAt: _asDate(data['validatedAt']),
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }
}
