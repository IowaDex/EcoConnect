import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

enum AnnouncementCategory {
  schedule,
  segregation,
  reminder,
  awareness,
  emergency,
  general,
  delay,
}

extension AnnouncementCategoryX on AnnouncementCategory {
  String get label => switch (this) {
        AnnouncementCategory.schedule => 'Collection schedule',
        AnnouncementCategory.segregation => 'Waste segregation',
        AnnouncementCategory.reminder => 'Community reminder',
        AnnouncementCategory.awareness => 'Environmental awareness',
        AnnouncementCategory.emergency => 'Emergency',
        AnnouncementCategory.general => 'General information',
        AnnouncementCategory.delay => 'Collection delay',
      };

  String get shortLabel => switch (this) {
        AnnouncementCategory.schedule => 'Schedule',
        AnnouncementCategory.segregation => 'Segregation',
        AnnouncementCategory.reminder => 'Reminder',
        AnnouncementCategory.awareness => 'Awareness',
        AnnouncementCategory.emergency => 'Emergency',
        AnnouncementCategory.general => 'General',
        AnnouncementCategory.delay => 'Delay',
      };

  IconData get icon => switch (this) {
        AnnouncementCategory.schedule => Icons.event_note_rounded,
        AnnouncementCategory.segregation => Icons.delete_sweep_rounded,
        AnnouncementCategory.reminder => Icons.campaign_rounded,
        AnnouncementCategory.awareness => Icons.eco_rounded,
        AnnouncementCategory.emergency => Icons.warning_amber_rounded,
        AnnouncementCategory.general => Icons.info_outline_rounded,
        AnnouncementCategory.delay => Icons.schedule_rounded,
      };

  Color get color => switch (this) {
        AnnouncementCategory.schedule => AppColors.primary,
        AnnouncementCategory.segregation => const Color(0xFF00695C),
        AnnouncementCategory.reminder => const Color(0xFF6A1B9A),
        AnnouncementCategory.awareness => const Color(0xFF558B2F),
        AnnouncementCategory.emergency => AppColors.error,
        AnnouncementCategory.general => const Color(0xFF37474F),
        AnnouncementCategory.delay => const Color(0xFFEF6C00),
      };

  static AnnouncementCategory fromName(String? name) =>
      AnnouncementCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => AnnouncementCategory.general,
      );
}

enum AnnouncementStatus { draft, published }

extension AnnouncementStatusX on AnnouncementStatus {
  String get label => this == AnnouncementStatus.published ? 'Published' : 'Draft';
  static AnnouncementStatus fromName(String? name) =>
      name == 'published' ? AnnouncementStatus.published : AnnouncementStatus.draft;
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A barangay announcement shown on the resident dashboard.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.image,
    this.status = AnnouncementStatus.published,
    this.publishAt,
    this.createdAt,
    this.updatedAt,
    this.authorId,
    this.authorName,
    this.barangay,
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementCategory category;
  final UploadPayload? image;
  final AnnouncementStatus status;
  final DateTime? publishAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authorId;
  final String? authorName;
  final String? barangay;

  bool get isPublished => status == AnnouncementStatus.published;

  bool get isLive {
    if (!isPublished) return false;
    final at = publishAt;
    return at == null || !at.isAfter(DateTime.now());
  }

  String get imageUrl => image?.dataUrl ?? '';

  Announcement copyWith({
    String? title,
    String? body,
    AnnouncementCategory? category,
    UploadPayload? image,
    bool clearImage = false,
    AnnouncementStatus? status,
    DateTime? publishAt,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      image: clearImage ? null : (image ?? this.image),
      status: status ?? this.status,
      publishAt: publishAt ?? this.publishAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorId: authorId,
      authorName: authorName,
      barangay: barangay,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'category': category.name,
        'image': image?.toMap(),
        'status': status.name,
        'publishAt': publishAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(publishAt!),
        'updatedAt': FieldValue.serverTimestamp(),
        'authorId': authorId,
        'authorName': authorName,
        'barangay': barangay,
      };

  static Announcement fromDoc(String id, Map<String, dynamic> data) {
    return Announcement(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Untitled announcement',
      body: (data['body'] as String?) ?? '',
      category: AnnouncementCategoryX.fromName(data['category'] as String?),
      image: UploadPayload.fromMap(data['image']),
      status: AnnouncementStatusX.fromName(data['status'] as String?),
      publishAt: _asDate(data['publishAt']),
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
      authorId: data['authorId'] as String?,
      authorName: data['authorName'] as String?,
      barangay: data['barangay'] as String?,
    );
  }
}
