import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// What went wrong on the road, from the crew's point of view.
///
/// The driver is not filing a delay — Iswim owns that decision. This is the
/// report that lets Iswim know a round may run late before anyone has to guess
/// why the truck stopped moving.
enum DriverIncidentKind { accident, breakdown, roadBlock, medical, other }

extension DriverIncidentKindX on DriverIncidentKind {
  String get label => switch (this) {
    DriverIncidentKind.accident => 'Accident',
    DriverIncidentKind.breakdown => 'Truck breakdown',
    DriverIncidentKind.roadBlock => 'Road blocked',
    DriverIncidentKind.medical => 'Medical emergency',
    DriverIncidentKind.other => 'Other',
  };

  IconData get icon => switch (this) {
    DriverIncidentKind.accident => Icons.car_crash_rounded,
    DriverIncidentKind.breakdown => Icons.build_circle_outlined,
    DriverIncidentKind.roadBlock => Icons.block_rounded,
    DriverIncidentKind.medical => Icons.medical_services_outlined,
    DriverIncidentKind.other => Icons.report_problem_outlined,
  };

  static DriverIncidentKind fromName(String? name) =>
      DriverIncidentKind.values.firstWhere(
        (kind) => kind.name == name,
        orElse: () => DriverIncidentKind.other,
      );
}

enum DriverIncidentStatus { open, acknowledged, closed }

extension DriverIncidentStatusX on DriverIncidentStatus {
  String get label => switch (this) {
    DriverIncidentStatus.open => 'Waiting for Iswim',
    DriverIncidentStatus.acknowledged => 'Seen by Iswim',
    DriverIncidentStatus.closed => 'Closed',
  };

  static DriverIncidentStatus fromName(String? name) =>
      DriverIncidentStatus.values.firstWhere(
        (status) => status.name == name,
        orElse: () => DriverIncidentStatus.open,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A report a crew member files from the truck. Stored at
/// `driver_incidents/{id}` and read by the Iswim desk.
class DriverIncident {
  const DriverIncident({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.plateNumber,
    required this.kind,
    required this.description,
    required this.status,
    this.zone = '',
    this.ticketId,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String plateNumber;
  final String zone;
  final DriverIncidentKind kind;
  final String description;
  final DriverIncidentStatus status;
  final String? ticketId;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;

  static DriverIncident? fromDoc(String id, Map<String, dynamic> data) =>
      DriverIncident(
        id: id,
        driverId: data['driverId'] as String? ?? '',
        driverName: data['driverName'] as String? ?? 'Crew',
        plateNumber: data['plateNumber'] as String? ?? '',
        zone: data['zone'] as String? ?? '',
        kind: DriverIncidentKindX.fromName(data['kind'] as String?),
        description: data['description'] as String? ?? '',
        status: DriverIncidentStatusX.fromName(data['status'] as String?),
        ticketId: data['ticketId'] as String?,
        latitude: (data['lat'] as num?)?.toDouble(),
        longitude: (data['lng'] as num?)?.toDouble(),
        createdAt: _asDate(data['createdAt']),
        acknowledgedAt: _asDate(data['acknowledgedAt']),
        acknowledgedByName: data['acknowledgedByName'] as String?,
      );
}
