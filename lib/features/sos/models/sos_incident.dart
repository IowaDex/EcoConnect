import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Where an SOS incident sits in the DSQC → District Officer → Barangay chain.
///
/// Four steps only. Opening the incident acknowledges it and the first call to
/// the barangay moves it to coordinating, so the officer never walks a ladder
/// of buttons. The status is written by a person, never inferred from a call
/// ending: a finished call does not resolve an incident.
enum SosStatus { newAlert, acknowledged, coordinating, resolved }

extension SosStatusX on SosStatus {
  String get wireName => name;

  String get label => switch (this) {
    SosStatus.newAlert => 'New Alert',
    SosStatus.acknowledged => 'Acknowledged',
    SosStatus.coordinating => 'Coordinating',
    SosStatus.resolved => 'Resolved',
  };

  String get shortLabel => label;

  Color get color => switch (this) {
    SosStatus.newAlert => AppColors.error,
    SosStatus.acknowledged => const Color(0xFF1565C0),
    SosStatus.coordinating => const Color(0xFF00838F),
    SosStatus.resolved => AppColors.inkMuted,
  };

  IconData get icon => switch (this) {
    SosStatus.newAlert => Icons.priority_high_rounded,
    SosStatus.acknowledged => Icons.check_circle_outline_rounded,
    SosStatus.coordinating => Icons.phone_in_talk_rounded,
    SosStatus.resolved => Icons.task_alt_rounded,
  };

  bool get isOpen => this != SosStatus.resolved;

  /// The one step this status still needs from the officer. Empty when the
  /// incident is resolved or already as far as it can go on its own.
  SosStatus? get nextStep => switch (this) {
    SosStatus.newAlert => SosStatus.acknowledged,
    SosStatus.acknowledged => SosStatus.coordinating,
    SosStatus.coordinating => SosStatus.resolved,
    SosStatus.resolved => null,
  };

  /// Reads both the current four names and the seven names written before the
  /// workflow was simplified, so old incidents keep their real progress.
  static SosStatus fromName(String? name) => switch (name) {
    'newAlert' || 'pending' => SosStatus.newAlert,
    'acknowledged' || 'received' => SosStatus.acknowledged,
    'coordinating' ||
    'contactingBarangay' ||
    'barangayNotified' ||
    'coordinationCompleted' => SosStatus.coordinating,
    'resolved' => SosStatus.resolved,
    _ => SosStatus.newAlert,
  };
}

/// One garbage-truck incident filed by DSQC at `sos_incidents/{id}`.
///
/// Everything the District Officer needs is copied onto the record when it is
/// sent, so the officer never has to call DSQC to ask what happened.
class SosIncident {
  const SosIncident({
    required this.id,
    required this.code,
    required this.description,
    required this.reason,
    required this.district,
    required this.barangay,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.incidentAt,
    this.truckPlate,
    this.route,
    this.officerUids = const [],
    this.createdAt,
    this.notifiedAt,
    this.receivedAt,
    this.acknowledgedAt,
    this.coordinatingAt,
    this.statusUpdatedAt,
    this.statusUpdatedBy,
    this.statusUpdatedByName,
    this.resolvedAt,
    this.resolvedBy,
    this.resolvedByName,
    this.resolutionNote,
  });

  final String id;

  /// `SOS-2026-0001`.
  final String code;

  final String description;

  /// What ISWIM reported: traffic, breakdown, missed collection, and so on.
  final String reason;

  final String district;
  final String barangay;

  /// The date and time the incident happened, stored as one instant.
  final DateTime? incidentAt;

  final String? truckPlate;
  final String? route;

  final SosStatus status;

  final String createdBy;
  final String createdByName;

  /// The District Officers this incident was dispatched to. Empty when no
  /// officer covered the district at send time.
  final List<String> officerUids;

  final DateTime? createdAt;
  final DateTime? notifiedAt;
  final DateTime? receivedAt;
  final DateTime? acknowledgedAt;

  /// Stamped the first time the officer rings the barangay about it.
  final DateTime? coordinatingAt;
  final DateTime? statusUpdatedAt;
  final String? statusUpdatedBy;
  final String? statusUpdatedByName;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolvedByName;

  /// What the officer did about it, written when the incident is resolved.
  final String? resolutionNote;

  bool get isOpen => status.isOpen;

  bool get isUnassigned => officerUids.isEmpty;

  String get location => [barangay, district]
      .where((part) => part.trim().isNotEmpty)
      .join(' · ');

  static SosIncident? fromDoc(String id, Map<String, dynamic> data) {
    final code = data['code'] as String?;
    final description = data['description'] as String?;
    final district = data['district'] as String?;
    final barangay = data['barangay'] as String?;
    if (code == null || description == null || district == null || barangay == null) {
      return null;
    }
    final officers = data['officerUids'];
    return SosIncident(
      id: id,
      code: code,
      description: description,
      reason: (data['reason'] as String?) ?? '',
      district: district,
      barangay: barangay,
      incidentAt: _date(data['incidentAt']),
      truckPlate: data['truckPlate'] as String?,
      route: data['route'] as String?,
      status: SosStatusX.fromName(data['status'] as String?),
      createdBy: (data['createdBy'] as String?) ?? '',
      createdByName: (data['createdByName'] as String?) ?? 'City Hall · DSQC',
      officerUids: officers is List
          ? officers.whereType<String>().toList(growable: false)
          : const [],
      createdAt: _date(data['createdAt']),
      notifiedAt: _date(data['notifiedAt']),
      receivedAt: _date(data['receivedAt']),
      acknowledgedAt: _date(data['acknowledgedAt']),
      coordinatingAt: _date(data['coordinatingAt']),
      statusUpdatedAt: _date(data['statusUpdatedAt']),
      statusUpdatedBy: data['statusUpdatedBy'] as String?,
      statusUpdatedByName: data['statusUpdatedByName'] as String?,
      resolvedAt: _date(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
      resolvedByName: data['resolvedByName'] as String?,
      resolutionNote: data['resolutionNote'] as String?,
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
