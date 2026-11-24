import 'package:cloud_firestore/cloud_firestore.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/call_log.dart';
import '../models/call_session.dart';

/// Firestore side of the in-app call.
///
/// `calls/{id}` is both the invitation and the WebRTC signalling channel.
/// `call_logs/{id}` is the durable history the District Officer reads after
/// the call. Both collections are owned by this service; screens never write
/// a path themselves.
class CallService {
  CallService({FirebaseFirestore? firestore, NotificationService? notifications})
    : _db = firestore ?? FirebaseFirestore.instance,
      _notifications = notifications ?? NotificationService();

  final FirebaseFirestore _db;
  final NotificationService _notifications;

  CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection('calls');

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('call_logs');

  /// Calls still ringing. The CallProvider filters the result to the signed-in
  /// desk or person, because one document may be addressed to a whole role.
  Stream<List<CallSession>> watchRinging() => _calls
      .where('status', isEqualTo: CallStatus.ringing.name)
      .limit(20)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => CallSession.fromDoc(doc.id, doc.data()))
            .whereType<CallSession>()
            .toList(growable: false),
      );

  Stream<CallSession?> watchCall(String id) => _calls.doc(id).snapshots().map(
    (snap) => snap.exists
        ? CallSession.fromDoc(snap.id, snap.data()!)
        : null,
  );

  /// The history is queried by participant so both ends see the same call.
  Stream<List<CallLog>> watchHistory(String uid) => _logs
      .where('participantIds', arrayContains: uid)
      .limit(100)
      .snapshots()
      .map(_sortedLogs);

  /// City Hall sees every call, not only the ones it took part in. The rules
  /// already allow it to read the whole collection.
  Stream<List<CallLog>> watchAllHistory() =>
      _logs.limit(200).snapshots().map(_sortedLogs);

  List<CallLog> _sortedLogs(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final logs = snap.docs
        .map((doc) => CallLog.fromDoc(doc.id, doc.data()))
        .whereType<CallLog>()
        .toList();
    logs.sort((a, b) {
      final aDate = a.startedAt ?? a.endedAt;
      final bDate = b.startedAt ?? b.endedAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return logs;
  }

  /// The calls tied to one SOS incident, for the incident's reference panel.
  ///
  /// An officer's query is constrained by `participantIds` so the security
  /// rules can prove it; City Hall may read every log, so it can query by
  /// incident directly. The officer's result is narrowed here instead of with
  /// a composite index.
  Stream<List<CallLog>> watchForIncident(
    String incidentId, {
    required String viewerUid,
    bool all = false,
  }) {
    final query = all
        ? _logs.where('incidentId', isEqualTo: incidentId)
        : _logs.where('participantIds', arrayContains: viewerUid);
    return query.limit(100).snapshots().map((snap) {
      final logs = snap.docs
          .map((doc) => CallLog.fromDoc(doc.id, doc.data()))
          .whereType<CallLog>()
          .where((log) => log.incidentId == incidentId)
          .toList();
      logs.sort((a, b) {
        final aDate = a.startedAt ?? a.endedAt;
        final bDate = b.startedAt ?? b.endedAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return logs;
    });
  }

  Future<String> create({
    required String fromUid,
    required String fromName,
    required String fromRole,
    required String toRole,
    String? toUid,
    String context = 'general',
    String? reference,
    String? delayId,
    String? barangay,
    String? district,
    String? incidentId,
    String? note,
  }) async {
    final ref = _calls.doc();
    await ref.set({
      'fromUid': fromUid,
      'fromName': fromName,
      'fromRole': fromRole,
      'toRole': toRole,
      if (toUid != null && toUid.isNotEmpty) 'toUid': toUid,
      'status': CallStatus.ringing.name,
      'context': context,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (delayId != null && delayId.isNotEmpty) 'delayId': delayId,
      if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
      if (district != null && district.isNotEmpty) 'district': district,
      if (incidentId != null && incidentId.isNotEmpty) 'incidentId': incidentId,
      if (note != null && note.isNotEmpty) 'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'callerCandidates': <Map<String, dynamic>>[],
      'calleeCandidates': <Map<String, dynamic>>[],
    });

    // A live call document only reaches the app while it is open. The desk
    // notification is what makes the phone buzz when the app is in the
    // background, and it is also the record that the call was attempted.
    await _notifyDesk(
      toRole,
      toUid: toUid,
      title: 'Incoming ${_roleLabel(fromRole)} call',
      body: fromName.trim().isEmpty
          ? '${_roleLabel(fromRole)} is calling.'
          : '$fromName is calling${reference == null ? '' : ' · $reference'}.',
      callId: ref.id,
      context: context,
    );

    return ref.id;
  }

  Future<void> sendOffer(String id, Map<String, dynamic> offer) =>
      _calls.doc(id).update({
        'offer': offer,
        'offerAt': FieldValue.serverTimestamp(),
      });

  Future<void> sendAnswer(String id, Map<String, dynamic> answer) =>
      _calls.doc(id).update({
        'answer': answer,
        'answerAt': FieldValue.serverTimestamp(),
      });

  Future<void> addCandidates(
    String id, {
    required bool fromCaller,
    required List<Map<String, dynamic>> candidates,
  }) {
    if (candidates.isEmpty) return Future.value();
    return _calls.doc(id).update({
      if (fromCaller) 'callerCandidates': FieldValue.arrayUnion(candidates),
      if (!fromCaller) 'calleeCandidates': FieldValue.arrayUnion(candidates),
    });
  }

  /// The first person on the addressed desk to answer wins. A transaction
  /// re-reads the document so two phones tapping Accept at the same time
  /// cannot both become the active callee.
  Future<CallSession?> accept(
    String id, {
    required String uid,
    required String name,
  }) async {
    final ref = _calls.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['status'] != CallStatus.ringing.name) return;
      tx.update(ref, {
        'status': CallStatus.active.name,
        'calleeId': uid,
        'calleeName': name,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
    final snap = await ref.get();
    return snap.exists ? CallSession.fromDoc(snap.id, snap.data()!) : null;
  }

  Future<void> decline(
    String id, {
    required String uid,
    required String name,
  }) async {
    final ref = _calls.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final call = CallSession.fromDoc(snap.id, snap.data()!)!;
    if (!call.isRinging) return;
    await ref.update({
      'status': CallStatus.declined.name,
      'calleeId': uid,
      'calleeName': name,
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': 0,
    });
    await writeLog(
      CallSession(
        id: call.id,
        fromUid: call.fromUid,
        fromName: call.fromName,
        fromRole: call.fromRole,
        toRole: call.toRole,
        toUid: call.toUid,
        calleeId: uid,
        calleeName: name,
        status: CallStatus.declined,
        context: call.context,
        reference: call.reference,
        delayId: call.delayId,
        barangay: call.barangay,
        district: call.district,
        incidentId: call.incidentId,
        createdAt: call.createdAt,
        endedAt: DateTime.now(),
      ),
      outcome: CallOutcome.declined,
      viewerUid: uid,
    );
  }

  /// Called when the ring timer runs out on the officer's phone. It is also
  /// written when the caller gives up, so the history still shows the attempt.
  Future<void> markMissed(
    String id, {
    String? uid,
    String? name,
    CallOutcome outcome = CallOutcome.missed,
  }) async {
    final ref = _calls.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final call = CallSession.fromDoc(snap.id, snap.data()!)!;
    if (!call.isRinging) return;
    await ref.update({
      'status': outcome == CallOutcome.cancelled
          ? CallStatus.ended.name
          : CallStatus.missed.name,
      if (uid != null) 'calleeId': uid,
      if (name != null) 'calleeName': name,
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': 0,
    });
    await writeLog(
      CallSession(
        id: call.id,
        fromUid: call.fromUid,
        fromName: call.fromName,
        fromRole: call.fromRole,
        toRole: call.toRole,
        toUid: call.toUid,
        calleeId: uid ?? call.calleeId,
        calleeName: name ?? call.calleeName,
        status: CallStatus.missed,
        context: call.context,
        reference: call.reference,
        delayId: call.delayId,
        barangay: call.barangay,
        district: call.district,
        incidentId: call.incidentId,
        createdAt: call.createdAt,
        endedAt: DateTime.now(),
      ),
      outcome: outcome,
      viewerUid: uid,
    );
  }

  /// The audio path never came up, or dropped and could not recover. The call
  /// is closed as failed and the attempt still appears in the history.
  Future<void> markFailed(
    String id, {
    required String viewerUid,
    String? reason,
  }) async {
    final ref = _calls.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final call = CallSession.fromDoc(snap.id, snap.data()!)!;
    if (call.status == CallStatus.ended ||
        call.status == CallStatus.failed ||
        call.status == CallStatus.declined ||
        call.status == CallStatus.missed) {
      return;
    }
    final now = DateTime.now();
    final started = call.acceptedAt;
    final seconds = started == null
        ? 0
        : now.difference(started).inSeconds.clamp(0, 86400);
    await ref.update({
      'status': CallStatus.failed.name,
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': seconds,
    });
    await writeLog(
      CallSession(
        id: call.id,
        fromUid: call.fromUid,
        fromName: call.fromName,
        fromRole: call.fromRole,
        toRole: call.toRole,
        toUid: call.toUid,
        calleeId: call.calleeId,
        calleeName: call.calleeName,
        status: CallStatus.failed,
        context: call.context,
        reference: call.reference,
        delayId: call.delayId,
        barangay: call.barangay,
        district: call.district,
        incidentId: call.incidentId,
        createdAt: call.createdAt,
        acceptedAt: call.acceptedAt,
        endedAt: now,
        durationSeconds: seconds,
      ),
      outcome: CallOutcome.failed,
      viewerUid: viewerUid,
      durationSeconds: seconds,
      failureReason: reason ?? 'The audio connection could not be established.',
    );
  }

  Future<void> end(String id, {required String viewerUid}) async {
    final ref = _calls.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final call = CallSession.fromDoc(snap.id, snap.data()!)!;
    if (call.status != CallStatus.active) return;
    final now = DateTime.now();
    final started = call.acceptedAt ?? now;
    final seconds = now.difference(started).inSeconds.clamp(0, 86400);
    await ref.update({
      'status': CallStatus.ended.name,
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': seconds,
    });
    await writeLog(
      CallSession(
        id: call.id,
        fromUid: call.fromUid,
        fromName: call.fromName,
        fromRole: call.fromRole,
        toRole: call.toRole,
        toUid: call.toUid,
        calleeId: call.calleeId,
        calleeName: call.calleeName,
        status: CallStatus.ended,
        context: call.context,
        reference: call.reference,
        delayId: call.delayId,
        barangay: call.barangay,
        district: call.district,
        incidentId: call.incidentId,
        note: call.note,
        createdAt: call.createdAt,
        acceptedAt: call.acceptedAt,
        endedAt: now,
        durationSeconds: seconds,
      ),
      outcome: CallOutcome.completed,
      viewerUid: viewerUid,
      durationSeconds: seconds,
    );
  }

  /// Upserts the durable row. `id` is the call id, so the second phone to
  /// finish the call updates the same record rather than duplicating it.
  Future<void> writeLog(
    CallSession call, {
    required CallOutcome outcome,
    String? viewerUid,
    int? durationSeconds,
    String? failureReason,
  }) {
    final participants = <String>{
      call.fromUid,
      if (call.calleeId != null && call.calleeId!.isNotEmpty) call.calleeId!,
      if (call.toUid != null && call.toUid!.isNotEmpty) call.toUid!,
      if (viewerUid != null && viewerUid.isNotEmpty) viewerUid,
    }.toList(growable: false);
    // The callee is the person who answered, or the one the call was aimed at.
    final receiverUid = (call.calleeId?.isNotEmpty ?? false)
        ? call.calleeId
        : call.toUid;
    final receiverName = (call.calleeName?.trim().isNotEmpty ?? false)
        ? call.calleeName!.trim()
        : null;
    return _logs.doc(call.id).set({
      'callId': call.id,
      'fromUid': call.fromUid,
      'fromName': call.fromName,
      'fromRole': call.fromRole,
      'toRole': call.toRole,
      if (receiverUid != null) 'toUid': receiverUid,
      if (receiverName != null) 'toName': receiverName,
      'outcome': outcome.name,
      'status': call.status.name,
      'context': call.context,
      if (call.reference != null) 'reference': call.reference,
      if (call.delayId != null) 'delayId': call.delayId,
      if (call.barangay != null) 'barangay': call.barangay,
      if (call.district != null) 'district': call.district,
      if (call.incidentId != null) 'incidentId': call.incidentId,
      'startedAt': call.createdAt ?? FieldValue.serverTimestamp(),
      if (call.acceptedAt != null) 'acceptedAt': call.acceptedAt,
      'endedAt': call.endedAt ?? FieldValue.serverTimestamp(),
      'durationSeconds': durationSeconds ?? call.durationSeconds,
      'participantIds': participants,
      if (failureReason != null) 'failureReason': failureReason,
      'hasRecording': false,
      'recordingUrl': null,
    }, SetOptions(merge: true));
  }

  Future<void> _notifyDesk(
    String toRole, {
    String? toUid,
    required String title,
    required String body,
    required String callId,
    required String context,
  }) async {
    final data = {'kind': 'incomingCall', 'callId': callId, 'context': context};
    // A named callee gets a personal push so the other officers on the desk
    // are not rung for a call that is not theirs.
    if (toUid != null && toUid.isNotEmpty) {
      await _notifications.push(
        userId: toUid,
        title: title,
        body: body,
        type: AppNotificationType.call,
        data: data,
      );
      return;
    }
    switch (toRole) {
      case 'districtOfficer':
        await _notifications.notifyDistrictOfficer(
          title: title,
          body: body,
          type: AppNotificationType.call,
          data: data,
        );
      case 'cityHall':
        await _notifications.notifyCityHall(
          title: title,
          body: body,
          type: AppNotificationType.call,
          data: data,
        );
      case 'admin':
        await _notifications.notifyStaff(
          title: title,
          body: body,
          type: AppNotificationType.call,
          data: data,
        );
      case 'iswim':
        await _notifications.notifyIswim(
          title: title,
          body: body,
          type: AppNotificationType.call,
          data: data,
        );
    }
  }

  static String _roleLabel(String role) => switch (role) {
    'cityHall' => 'City Hall · DSQC',
    'districtOfficer' => 'District Officer',
    'admin' => 'Barangay staff',
    'iswim' => 'Iswim',
    _ => 'EcoConnect',
  };
}
