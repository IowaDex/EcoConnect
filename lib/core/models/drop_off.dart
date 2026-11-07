import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Accepted recyclables and the points each kilo is worth.
enum RecyclableMaterial { plastic, paper, glass, metal, ewaste, organic }

extension RecyclableMaterialX on RecyclableMaterial {
  String get label => switch (this) {
        RecyclableMaterial.plastic => 'Plastic',
        RecyclableMaterial.paper => 'Paper & cardboard',
        RecyclableMaterial.glass => 'Glass',
        RecyclableMaterial.metal => 'Metal (tin / aluminum)',
        RecyclableMaterial.ewaste => 'E-waste',
        RecyclableMaterial.organic => 'Organic / compost',
      };

  String get shortLabel => switch (this) {
        RecyclableMaterial.plastic => 'Plastic',
        RecyclableMaterial.paper => 'Paper',
        RecyclableMaterial.glass => 'Glass',
        RecyclableMaterial.metal => 'Metal',
        RecyclableMaterial.ewaste => 'E-waste',
        RecyclableMaterial.organic => 'Organic',
      };

  /// Points credited per kilogram at the barangay drop-off station.
  int get pointsPerKg => switch (this) {
        RecyclableMaterial.plastic => 10,
        RecyclableMaterial.paper => 6,
        RecyclableMaterial.glass => 5,
        RecyclableMaterial.metal => 20,
        RecyclableMaterial.ewaste => 25,
        RecyclableMaterial.organic => 3,
      };

  IconData get icon => switch (this) {
        RecyclableMaterial.plastic => Icons.local_drink_outlined,
        RecyclableMaterial.paper => Icons.description_outlined,
        RecyclableMaterial.glass => Icons.wine_bar_outlined,
        RecyclableMaterial.metal => Icons.hardware_outlined,
        RecyclableMaterial.ewaste => Icons.memory_outlined,
        RecyclableMaterial.organic => Icons.eco_outlined,
      };

  Color get color => switch (this) {
        RecyclableMaterial.plastic => const Color(0xFF3E7CB1),
        RecyclableMaterial.paper => const Color(0xFF9A7B4F),
        RecyclableMaterial.glass => const Color(0xFF4F9A8A),
        RecyclableMaterial.metal => const Color(0xFF6F7F69),
        RecyclableMaterial.ewaste => const Color(0xFF8A5A9A),
        RecyclableMaterial.organic => AppColors.moss,
      };

  static RecyclableMaterial fromName(String? name) =>
      RecyclableMaterial.values.firstWhere(
        (m) => m.name == name,
        orElse: () => RecyclableMaterial.plastic,
      );
}

/// One drop-off at the barangay recycling station.
/// Stored at `dropOffs/{dropOffId}`.
class DropOff {
  const DropOff({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.material,
    required this.weightKg,
    required this.points,
    this.residentEmail,
    this.staffId,
    this.staffName,
    this.createdAt,
  });

  final String id;
  final String residentId;
  final String residentName;
  final String? residentEmail;
  final String? staffId;
  final String? staffName;
  final RecyclableMaterial material;
  final double weightKg;
  final int points;
  final DateTime? createdAt;

  /// The single source of truth for the station's pricing.
  static int pointsFor(RecyclableMaterial material, double weightKg) {
    if (weightKg <= 0) return 0;
    return (material.pointsPerKg * weightKg).round();
  }

  static DropOff fromDoc(String id, Map<String, dynamic> data) {
    return DropOff(
      id: id,
      residentId: (data['residentId'] as String?) ?? '',
      residentName: (data['residentName'] as String?) ?? 'Resident',
      residentEmail: data['residentEmail'] as String?,
      staffId: data['staffId'] as String?,
      staffName: data['staffName'] as String?,
      material: RecyclableMaterialX.fromName(data['material'] as String?),
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
