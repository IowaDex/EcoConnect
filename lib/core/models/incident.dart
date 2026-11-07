import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum IncidentCategory { missedCollection, illegalDumping, overflowingBin, other }

extension IncidentCategoryX on IncidentCategory {
  String get label => switch (this) {
        IncidentCategory.missedCollection => 'Missed collection',
        IncidentCategory.illegalDumping => 'Illegal dumping',
        IncidentCategory.overflowingBin => 'Overflowing bin',
        IncidentCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        IncidentCategory.missedCollection => Icons.local_shipping_outlined,
        IncidentCategory.illegalDumping => Icons.delete_outline,
        IncidentCategory.overflowingBin => Icons.delete_sweep_outlined,
        IncidentCategory.other => Icons.report_outlined,
      };
}

enum IncidentStatus { pending, resolved }

extension IncidentStatusX on IncidentStatus {
  String get label =>
      this == IncidentStatus.pending ? 'Pending' : 'Resolved';

  Color get color => this == IncidentStatus.pending
      ? const Color(0xFFF2B441)
      : AppColors.moss;

  static IncidentStatus fromName(String? name) =>
      name == 'resolved' ? IncidentStatus.resolved : IncidentStatus.pending;
}

class Incident {
  const Incident({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.category,
    required this.description,
    required this.status,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  final String id;
  final String residentId;
  final String residentName;
  final IncidentCategory category;
  final String description;
  final IncidentStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  static Incident fromDoc(String id, Map<String, dynamic> data) => Incident(
        id: id,
        residentId: data['residentId'] as String? ?? '',
        residentName: data['residentName'] as String? ?? 'Resident',
        category: IncidentCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => IncidentCategory.other,
        ),
        description: data['description'] as String? ?? '',
        status: IncidentStatusX.fromName(data['status'] as String?),
        latitude: (data['lat'] as num?)?.toDouble(),
        longitude: (data['lng'] as num?)?.toDouble(),
        createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      );
}
