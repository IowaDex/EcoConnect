import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

enum EventCategory {
  cleanup,
  treePlanting,
  recycling,
  education,
  collectionDay,
  other,
}

extension EventCategoryX on EventCategory {
  String get label => switch (this) {
        EventCategory.cleanup => 'Clean-up drive',
        EventCategory.treePlanting => 'Tree planting',
        EventCategory.recycling => 'Recycling program',
        EventCategory.education => 'Environmental seminar',
        EventCategory.collectionDay => 'Community collection day',
        EventCategory.other => 'Community event',
      };

  IconData get icon => switch (this) {
        EventCategory.cleanup => Icons.cleaning_services_rounded,
        EventCategory.treePlanting => Icons.park_rounded,
        EventCategory.recycling => Icons.recycling_rounded,
        EventCategory.education => Icons.school_rounded,
        EventCategory.collectionDay => Icons.local_shipping_rounded,
        EventCategory.other => Icons.groups_rounded,
      };

  Color get color => switch (this) {
        EventCategory.cleanup => const Color(0xFF00897B),
        EventCategory.treePlanting => AppColors.primary,
        EventCategory.recycling => const Color(0xFF2E7D32),
        EventCategory.education => const Color(0xFF5E35B1),
        EventCategory.collectionDay => const Color(0xFFEF6C00),
        EventCategory.other => const Color(0xFF455A64),
      };

  static EventCategory fromName(String? name) => EventCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => EventCategory.other,
      );
}

enum EventStatus { draft, published }

extension EventStatusX on EventStatus {
  String get label => this == EventStatus.published ? 'Published' : 'Draft';
  static EventStatus fromName(String? name) =>
      name == 'published' ? EventStatus.published : EventStatus.draft;
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A barangay environmental event.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.startAt,
    this.endAt,
    this.image,
    this.status = EventStatus.published,
    this.registrationInfo,
    this.contact,
    this.createdAt,
    this.updatedAt,
    this.authorId,
    this.authorName,
    this.barangay,
  });

  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final String location;
  final DateTime startAt;
  final DateTime? endAt;
  final UploadPayload? image;
  final EventStatus status;
  final String? registrationInfo;
  final String? contact;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authorId;
  final String? authorName;
  final String? barangay;

  bool get isPublished => status == EventStatus.published;

  bool get isCompleted {
    final end = endAt ?? startAt.add(const Duration(hours: 4));
    return end.isBefore(DateTime.now());
  }

  bool get isUpcoming => !isCompleted;

  String get imageUrl => image?.dataUrl ?? '';

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'category': category.name,
        'location': location,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
        'image': image?.toMap(),
        'status': status.name,
        'registrationInfo': registrationInfo,
        'contact': contact,
        'updatedAt': FieldValue.serverTimestamp(),
        'authorId': authorId,
        'authorName': authorName,
        'barangay': barangay,
      };

  static CommunityEvent fromDoc(String id, Map<String, dynamic> data) {
    final start = _asDate(data['startAt']) ?? DateTime.now();
    return CommunityEvent(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Community event',
      description: (data['description'] as String?) ?? '',
      category: EventCategoryX.fromName(data['category'] as String?),
      location: (data['location'] as String?) ?? 'Barangay hall',
      startAt: start,
      endAt: _asDate(data['endAt']),
      image: UploadPayload.fromMap(data['image']),
      status: EventStatusX.fromName(data['status'] as String?),
      registrationInfo: data['registrationInfo'] as String?,
      contact: data['contact'] as String?,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
      authorId: data['authorId'] as String?,
      authorName: data['authorName'] as String?,
      barangay: data['barangay'] as String?,
    );
  }
}
