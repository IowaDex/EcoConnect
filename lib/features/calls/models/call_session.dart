import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a call is in its short life.
///
/// `ringing` is the only state two devices act on: the caller has written the
/// invitation and the receiver is being alerted. `active` starts when one of
/// the invited people answers, and every other device stops ringing because
/// the document is no longer `ringing`.
enum CallStatus { ringing, active, declined, missed, ended, failed }

extension CallStatusX on CallStatus {
  static CallStatus fromName(String? name) => CallStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => CallStatus.ended,
  );

  String get label => switch (this) {
    CallStatus.ringing => 'Ringing',
    CallStatus.active => 'In progress',
    CallStatus.declined => 'Declined',
    CallStatus.missed => 'Missed',
    CallStatus.ended => 'Ended',
    CallStatus.failed => 'Failed',
  };
}

/// One in-app call document at `calls/{id}`.
///
/// The document doubles as the WebRTC signalling channel: `offer`, `answer`
/// and the two candidate arrays are written by the two phones. Keeping them on
/// the call itself avoids a second Firestore collection and means a call is
/// deleted or expired as one record.
class CallSession {
  const CallSession({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromRole,
    required this.toRole,
    required this.status,
    this.toUid,
    this.calleeId,
    this.calleeName,
    this.context = 'general',
    this.reference,
    this.delayId,
    this.barangay,
    this.district,
    this.incidentId,
    this.note,
    this.createdAt,
    this.acceptedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.offer,
    this.answer,
    this.callerCandidates = const [],
    this.calleeCandidates = const [],
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String fromRole;
  final String toRole;
  final CallStatus status;

  /// Set only when one named person is called (DSQC tapping a specific
  /// officer). A role-addressed call leaves this empty so any active account
  /// on that desk can answer.
  final String? toUid;

  final String? calleeId;
  final String? calleeName;

  /// `delay` when the call starts from a late collection, `sos` when it is
  /// part of an SOS incident.
  final String context;
  final String? reference;
  final String? delayId;
  final String? barangay;
  final String? district;
  final String? incidentId;
  final String? note;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final List<Map<String, dynamic>> callerCandidates;
  final List<Map<String, dynamic>> calleeCandidates;

  bool get isRinging => status == CallStatus.ringing;

  /// The other party as this viewer sees them. A role-addressed call shows the
  /// desk until somebody answers, then the person who answered.
  String otherName(String viewerUid) {
    if (viewerUid == fromUid) {
      return calleeName?.trim().isNotEmpty == true
          ? calleeName!.trim()
          : _roleLabel(toRole);
    }
    return fromName.trim().isEmpty ? _roleLabel(fromRole) : fromName.trim();
  }

  String otherRole(String viewerUid) =>
      viewerUid == fromUid ? toRole : fromRole;

  static String _roleLabel(String role) => switch (role) {
    'cityHall' => 'City Hall · DSQC',
    'districtOfficer' => 'District Officer',
    'admin' => 'Barangay staff',
    'iswim' => 'Iswim',
    _ => 'EcoConnect',
  };

  static CallSession? fromDoc(String id, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String?;
    final toRole = data['toRole'] as String?;
    if (fromUid == null || toRole == null) return null;
    return CallSession(
      id: id,
      fromUid: fromUid,
      fromName: (data['fromName'] as String?) ?? '',
      fromRole: (data['fromRole'] as String?) ?? 'user',
      toRole: toRole,
      toUid: data['toUid'] as String?,
      calleeId: data['calleeId'] as String?,
      calleeName: data['calleeName'] as String?,
      status: CallStatusX.fromName(data['status'] as String?),
      context: (data['context'] as String?) ?? 'general',
      reference: data['reference'] as String?,
      delayId: data['delayId'] as String?,
      barangay: data['barangay'] as String?,
      district: data['district'] as String?,
      incidentId: data['incidentId'] as String?,
      note: data['note'] as String?,
      createdAt: _date(data['createdAt']),
      acceptedAt: _date(data['acceptedAt']),
      endedAt: _date(data['endedAt']),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      offer: _map(data['offer']),
      answer: _map(data['answer']),
      callerCandidates: _candidateList(data['callerCandidates']),
      calleeCandidates: _candidateList(data['calleeCandidates']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  static List<Map<String, dynamic>> _candidateList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }
}
