import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a delay report is sitting.
///
/// Iswim files it, DSQC reads it at City Hall, then it is pushed to the
/// district officer — who has no account, so the push is an alarm on the DSQC
/// device rather than a login — and finally the barangay gets the copy.
enum DelayStage { dsqc, districtOfficer, barangay, closed }

extension DelayStageX on DelayStage {
  String get wireName => switch (this) {
        DelayStage.dsqc => 'dsqc',
        DelayStage.districtOfficer => 'districtOfficer',
        DelayStage.barangay => 'barangay',
        DelayStage.closed => 'closed',
      };

  String get label => switch (this) {
        DelayStage.dsqc => 'Nasa DSQC',
        DelayStage.districtOfficer => 'Naipasa sa District Officer',
        DelayStage.barangay => 'Nasa Barangay',
        DelayStage.closed => 'Sarado',
      };

  static DelayStage fromName(String? name) => DelayStage.values.firstWhere(
        (s) => s.name == name,
        orElse: () => DelayStage.dsqc,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// Why a collection round ran late, filed by Iswim.
class DelayReport {
  const DelayReport({
    required this.id,
    required this.code,
    required this.plateNumber,
    required this.driverName,
    required this.reason,
    required this.minutesLate,
    required this.notes,
    required this.stage,
    required this.filedBy,
    required this.filedByName,
    this.ticketId,
    this.ticketCode,
    this.createdAt,
    this.forwardedAt,
    this.barangayAt,
    this.closedAt,
  });

  final String id;

  /// `DR-2026-0001`.
  final String code;
  final String plateNumber;
  final String driverName;
  final String reason;
  final int minutesLate;
  final String notes;
  final DelayStage stage;
  final String filedBy;
  final String filedByName;
  final String? ticketId;
  final String? ticketCode;
  final DateTime? createdAt;
  final DateTime? forwardedAt;
  final DateTime? barangayAt;
  final DateTime? closedAt;

  Map<String, dynamic> toMap() => {
        'code': code,
        'plateNumber': plateNumber,
        'driverName': driverName,
        'reason': reason,
        'minutesLate': minutesLate,
        'notes': notes,
        'stage': stage.wireName,
        'filedBy': filedBy,
        'filedByName': filedByName,
        if (ticketId != null) 'ticketId': ticketId,
        if (ticketCode != null) 'ticketCode': ticketCode,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static DelayReport? fromDoc(String id, Map<String, dynamic> data) {
    return DelayReport(
      id: id,
      code: data['code'] as String? ?? id,
      plateNumber: data['plateNumber'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      minutesLate: (data['minutesLate'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String? ?? '',
      stage: DelayStageX.fromName(data['stage'] as String?),
      filedBy: data['filedBy'] as String? ?? '',
      filedByName: data['filedByName'] as String? ?? 'Iswim',
      ticketId: data['ticketId'] as String?,
      ticketCode: data['ticketCode'] as String?,
      createdAt: _asDate(data['createdAt']),
      forwardedAt: _asDate(data['forwardedAt']),
      barangayAt: _asDate(data['barangayAt']),
      closedAt: _asDate(data['closedAt']),
    );
  }
}
