import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.documentPath,
    required this.actorUid,
    required this.actorType,
    required this.changedFields,
    required this.at,
    required this.outcome,
  });

  final String id;
  final String action;
  final String documentPath;
  final String? actorUid;
  final String actorType;
  final List<String> changedFields;
  final DateTime? at;
  final String outcome;

  factory AuditEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawAt = data['at'];
    final fields = data['changedFields'];
    return AuditEntry(
      id: document.id,
      action: data['action'] as String? ?? 'unknown',
      documentPath:
          data['documentPath'] as String? ?? data['targetUid'] as String? ?? '',
      actorUid: data['actorUid'] as String?,
      actorType: data['actorType'] as String? ?? 'user',
      changedFields: fields is List
          ? fields.whereType<String>().toList(growable: false)
          : const [],
      at: rawAt is Timestamp ? rawAt.toDate() : null,
      outcome: data['outcome'] as String? ?? 'committed',
    );
  }
}
