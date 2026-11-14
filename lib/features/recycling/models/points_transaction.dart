import 'package:cloud_firestore/cloud_firestore.dart';

/// One immutable row in the resident's points ledger.
///
/// Both station drop-offs and validated waste submissions write here, so the
/// balance on `users/{uid}.points` can always be reconciled line by line.
class PointsTransaction {
  const PointsTransaction({
    required this.id,
    required this.residentId,
    required this.points,
    required this.reason,
    required this.sourceType,
    this.sourceId,
    this.byName,
    this.createdAt,
  });

  final String id;
  final String residentId;
  final int points;
  final String reason;
  final String sourceType;
  final String? sourceId;
  final String? byName;
  final DateTime? createdAt;

  static PointsTransaction? fromDoc(String id, Map<String, dynamic> data) {
    final rawDate = data['createdAt'];
    return PointsTransaction(
      id: id,
      residentId: data['residentId'] as String? ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? 'Points credited',
      sourceType: data['sourceType'] as String? ?? 'adjustment',
      sourceId: data['sourceId'] as String?,
      byName: data['byName'] as String?,
      createdAt: rawDate is Timestamp ? rawDate.toDate() : null,
    );
  }
}
