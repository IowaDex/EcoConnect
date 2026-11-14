import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AppNotificationType {
  account,
  verification,
  waste,
  request,
  route,
  announcement,
  event,
  points,
  system,
  complaint,
}

extension AppNotificationTypeX on AppNotificationType {
  String get label => switch (this) {
        AppNotificationType.account => 'Account',
        AppNotificationType.verification => 'Verification',
        AppNotificationType.waste => 'Waste',
        AppNotificationType.request => 'Collection',
        AppNotificationType.route => 'Route',
        AppNotificationType.announcement => 'Announcement',
        AppNotificationType.event => 'Event',
        AppNotificationType.points => 'Points',
        AppNotificationType.system => 'System',
        AppNotificationType.complaint => 'Complaint',
      };

  IconData get icon => switch (this) {
        AppNotificationType.account => Icons.person_outline_rounded,
        AppNotificationType.verification => Icons.verified_user_outlined,
        AppNotificationType.waste => Icons.delete_outline_rounded,
        AppNotificationType.request => Icons.assignment_outlined,
        AppNotificationType.route => Icons.local_shipping_outlined,
        AppNotificationType.announcement => Icons.campaign_outlined,
        AppNotificationType.event => Icons.event_outlined,
        AppNotificationType.points => Icons.stars_rounded,
        AppNotificationType.system => Icons.notifications_none_rounded,
        AppNotificationType.complaint => Icons.report_outlined,
      };

  Color get color => switch (this) {
        AppNotificationType.account => const Color(0xFF1565C0),
        AppNotificationType.verification => AppColors.primary,
        AppNotificationType.waste => const Color(0xFF00695C),
        AppNotificationType.request => const Color(0xFF6A1B9A),
        AppNotificationType.route => const Color(0xFFEF6C00),
        AppNotificationType.announcement => const Color(0xFF00838F),
        AppNotificationType.event => const Color(0xFF558B2F),
        AppNotificationType.points => const Color(0xFFF9A825),
        AppNotificationType.system => AppColors.inkMuted,
        AppNotificationType.complaint => const Color(0xFFC62828),
      };

  static AppNotificationType fromName(String? name) =>
      AppNotificationType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => AppNotificationType.system,
      );
}

/// One in-app notification. Stored at notifications/{id}.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    this.createdAt,
    this.data = const {},
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final AppNotificationType type;
  final bool read;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  static AppNotification fromDoc(String id, Map<String, dynamic> data) {
    final rawDate = data['createdAt'];
    return AppNotification(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      title: (data['title'] as String?) ?? 'Notification',
      body: (data['body'] as String?) ?? '',
      type: AppNotificationTypeX.fromName(data['type'] as String?),
      read: data['read'] == true,
      createdAt: rawDate is Timestamp ? rawDate.toDate() : null,
      data: (data['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
