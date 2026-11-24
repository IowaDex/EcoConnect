import 'package:cloud_firestore/cloud_firestore.dart';

/// How a call finished. Kept separate from CallStatus because a log still
/// calls a finished call "completed" rather than "ended".
enum CallOutcome { completed, declined, missed, cancelled, failed }

extension CallOutcomeX on CallOutcome {
  static CallOutcome fromName(String? name) => CallOutcome.values.firstWhere(
    (outcome) => outcome.name == name,
    orElse: () => CallOutcome.completed,
  );

  String get label => switch (this) {
    CallOutcome.completed => 'Completed',
    CallOutcome.declined => 'Declined',
    CallOutcome.missed => 'Missed',
    CallOutcome.cancelled => 'Cancelled',
    CallOutcome.failed => 'Failed',
  };
}

/// One entry in the District Officer's call history at `call_logs/{id}`.
///
/// The id is the call id, so writing a log twice from both ends updates the
/// same record instead of producing two rows for one conversation.
class CallLog {
  const CallLog({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromRole,
    required this.toRole,
    required this.outcome,
    this.toUid,
    this.toName,
    this.context = 'general',
    this.reference,
    this.delayId,
    this.barangay,
    this.district,
    this.incidentId,
    this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.participantIds = const [],
    this.status,
    this.failureReason,
    this.hasRecording = false,
    this.recordingUrl,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String fromRole;
  final String toRole;
  final String? toUid;
  final String? toName;

  final CallOutcome outcome;

  final String context;
  final String? reference;
  final String? delayId;
  final String? barangay;

  /// The legislative district the call belonged to, copied from the caller so
  /// the history can be filtered the same way the incidents are.
  final String? district;
  final String? incidentId;

  final DateTime? startedAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  /// The state the call document finished in (ended, missed, declined…). Kept
  /// beside [outcome] because the two answer different questions: what the
  /// call did, and how it was closed.
  final String? status;

  /// Why the audio never came up, when it did not.
  final String? failureReason;

  /// Everyone who took part. The history screen queries this array so a call
  /// appears for both the officer and the desk that answered.
  final List<String> participantIds;

  /// Audio capture is done by the native call layer. The field is kept so a
  /// recording service can attach a file later without a schema migration.
  final bool hasRecording;
  final String? recordingUrl;

  bool get connected =>
      outcome == CallOutcome.completed && durationSeconds > 0;

  String contactFor(String viewerUid) {
    if (viewerUid == fromUid) {
      return (toName?.trim().isNotEmpty ?? false)
          ? toName!.trim()
          : _roleLabel(toRole);
    }
    return fromName.trim().isEmpty ? _roleLabel(fromRole) : fromName.trim();
  }

  String contactRoleFor(String viewerUid) =>
      viewerUid == fromUid ? toRole : fromRole;

  bool isOutgoing(String viewerUid) => viewerUid == fromUid;

  static String _roleLabel(String role) => switch (role) {
    'cityHall' => 'City Hall · DSQC',
    'districtOfficer' => 'District Officer',
    'admin' => 'Barangay staff',
    'iswim' => 'Iswim',
    _ => 'EcoConnect',
  };

  static CallLog? fromDoc(String id, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String?;
    final toRole = data['toRole'] as String?;
    if (fromUid == null || toRole == null) return null;
    final participants = data['participantIds'];
    return CallLog(
      id: id,
      fromUid: fromUid,
      fromName: (data['fromName'] as String?) ?? '',
      fromRole: (data['fromRole'] as String?) ?? 'user',
      toRole: toRole,
      toUid: data['toUid'] as String?,
      toName: data['toName'] as String?,
      outcome: CallOutcomeX.fromName(data['outcome'] as String?),
      context: (data['context'] as String?) ?? 'general',
      reference: data['reference'] as String?,
      delayId: data['delayId'] as String?,
      barangay: data['barangay'] as String?,
      district: data['district'] as String?,
      incidentId: data['incidentId'] as String?,
      startedAt: _date(data['startedAt']),
      acceptedAt: _date(data['acceptedAt']),
      endedAt: _date(data['endedAt']),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      status: data['status'] as String?,
      failureReason: data['failureReason'] as String?,
      participantIds: participants is List
          ? participants.whereType<String>().toList(growable: false)
          : const [],
      hasRecording: data['hasRecording'] == true,
      recordingUrl: data['recordingUrl'] as String?,
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
