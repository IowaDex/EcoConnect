import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

/// What a memo is, in the barangay's own language.
enum MemoKind { memo, endorsement, announcement, manualRequest }

extension MemoKindX on MemoKind {
  String get wireName => switch (this) {
        MemoKind.memo => 'memo',
        MemoKind.endorsement => 'endorsement',
        MemoKind.announcement => 'announcement',
        MemoKind.manualRequest => 'manualRequest',
      };

  String get label => switch (this) {
        MemoKind.memo => 'Memo',
        MemoKind.endorsement => 'Endorsement',
        MemoKind.announcement => 'Announcement',
        MemoKind.manualRequest => 'Manual request',
      };

  static MemoKind fromName(String? name) => MemoKind.values.firstWhere(
        (m) => m.wireName == name,
        orElse: () => MemoKind.memo,
      );
}

/// Where a memo is in its life.
///
/// `sent` — the author submitted it and the recipient has not opened it yet.
/// `received` — the recipient desk opened it.
/// `acknowledged` — the recipient signed it; the record is final.
enum MemoStatus { sent, received, acknowledged }

extension MemoStatusX on MemoStatus {
  String get wireName => switch (this) {
        MemoStatus.sent => 'sent',
        MemoStatus.received => 'received',
        MemoStatus.acknowledged => 'acknowledged',
      };

  String get label => switch (this) {
        MemoStatus.sent => 'Sent',
        MemoStatus.received => 'Received',
        MemoStatus.acknowledged => 'Signed',
      };

  bool get isFinal => this == MemoStatus.acknowledged;

  static MemoStatus fromName(String? name) => MemoStatus.values.firstWhere(
        (s) => s.wireName == name,
        orElse: () => MemoStatus.sent,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A memo, endorsement, announcement or manual request between City Hall,
/// Iswim and the barangay. Text plus an optional attachment (photo or PDF).
class Memo {
  const Memo({
    required this.id,
    required this.kind,
    required this.subject,
    required this.body,
    required this.fromName,
    required this.fromRole,
    required this.fromUid,
    required this.toChannel,
    this.attachment,
    this.status = MemoStatus.sent,
    this.createdAt,
    this.receivedAt,
    this.acknowledgedAt,
    this.acknowledgedByUid,
    this.acknowledgedByName,
    this.acknowledgementSignature,
    this.editedAt,
  });

  final String id;
  final MemoKind kind;
  final String subject;
  final String body;
  final String fromName;
  final String fromRole;
  final String fromUid;

  /// `iswim`, `barangay` or `cityHall`.
  final String toChannel;
  final UploadPayload? attachment;

  final MemoStatus status;
  final DateTime? createdAt;
  final DateTime? receivedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUid;
  final String? acknowledgedByName;

  /// Base64 PNG of the recipient's drawn signature, captured by
  /// `showSignatureSheet`.
  final String? acknowledgementSignature;

  final DateTime? editedAt;

  bool get isSigned => status == MemoStatus.acknowledged;

  /// True while the recipient can still edit the text.
  bool get isEditable => status == MemoStatus.sent;

  String get recipientLabel => switch (toChannel) {
        'iswim' => 'Iswim',
        'barangay' => 'Barangay',
        _ => 'City Hall',
      };

  Map<String, dynamic> toMap() => {
        'kind': kind.wireName,
        'subject': subject,
        'body': body,
        'fromName': fromName,
        'fromRole': fromRole,
        'fromUid': fromUid,
        'toChannel': toChannel,
        'status': MemoStatus.sent.wireName,
        if (attachment != null) 'attachment': attachment!.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  static Memo? fromDoc(String id, Map<String, dynamic> data) => Memo(
        id: id,
        kind: MemoKindX.fromName(data['kind'] as String?),
        subject: data['subject'] as String? ?? '(no subject)',
        body: data['body'] as String? ?? '',
        fromName: data['fromName'] as String? ?? '',
        fromRole: data['fromRole'] as String? ?? '',
        fromUid: data['fromUid'] as String? ?? '',
        toChannel: data['toChannel'] as String? ?? 'cityHall',
        // Records written before attachments were typed stored a bare data URL
        // in `photo`; read it as an image so old memos keep their file.
        attachment: UploadPayload.fromMap(data['attachment']) ??
            _legacyPhoto(data['photo']),
        status: MemoStatusX.fromName(data['status'] as String?),
        createdAt: _asDate(data['createdAt']),
        receivedAt: _asDate(data['receivedAt']),
        acknowledgedAt: _asDate(data['acknowledgedAt']),
        acknowledgedByUid: data['acknowledgedByUid'] as String?,
        acknowledgedByName: data['acknowledgedByName'] as String?,
        acknowledgementSignature:
            data['acknowledgementSignature'] as String?,
        editedAt: _asDate(data['editedAt']),
      );

  static UploadPayload? _legacyPhoto(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return UploadPayload(
      dataUrl: raw,
      fileName: 'attachment.jpg',
      mimeType: 'image/jpeg',
      bytes: 0,
    );
  }
}

class MemoException implements Exception {
  const MemoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One entry in the outgoing email log.
///
/// The project has no SMTP credentials, so an "email" is recorded here and
/// shown to City Hall instead of silently pretending it was delivered.
class EmailLogEntry {
  const EmailLogEntry({
    required this.id,
    required this.to,
    required this.subject,
    required this.body,
    required this.byName,
    this.sentAt,
  });

  final String id;
  final String to;
  final String subject;
  final String body;
  final String byName;
  final DateTime? sentAt;

  static EmailLogEntry? fromDoc(String id, Map<String, dynamic> data) =>
      EmailLogEntry(
        id: id,
        to: data['to'] as String? ?? '',
        subject: data['subject'] as String? ?? '',
        body: data['body'] as String? ?? '',
        byName: data['byName'] as String? ?? '',
        sentAt: _asDate(data['sentAt']),
      );
}

class MemoService {
  MemoService._();
  static final MemoService instance = MemoService._();
  factory MemoService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('memos');

  /// Memos addressed to one desk, newest first.
  Stream<List<Memo>> watchForChannel(String channel, {int limit = 60}) => _col
      .where('toChannel', isEqualTo: channel)
      .limit(limit)
      .snapshots()
      .map((snap) {
        final memos = snap.docs
            .map((doc) => Memo.fromDoc(doc.id, doc.data()))
            .whereType<Memo>()
            .toList();
        memos.sort(_newestFirst);
        return memos;
      });

  /// Memos sent from one desk, so the office can track their status.
  ///
  /// A desk can have more than one account (for example two City Hall
  /// officers), and the sent history belongs to the office, not to whoever
  /// happened to press Send.
  Stream<List<Memo>> watchSentByDesk(String fromRole) => _col
      .where('fromRole', isEqualTo: fromRole)
      .limit(60)
      .snapshots()
      .map((snap) {
        final memos = snap.docs
            .map((doc) => Memo.fromDoc(doc.id, doc.data()))
            .whereType<Memo>()
            .toList();
        memos.sort(_newestFirst);
        return memos;
      });

  Stream<Memo?> watchOne(String id) => _col.doc(id).snapshots().map(
        (doc) => doc.exists ? Memo.fromDoc(doc.id, doc.data()!) : null,
      );

  Stream<List<EmailLogEntry>> watchEmailLog() => _db
      .collection('email_log')
      .orderBy('sentAt', descending: true)
      .limit(40)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => EmailLogEntry.fromDoc(doc.id, doc.data()))
          .whereType<EmailLogEntry>()
          .toList());

  /// Writes the memo, then alerts the desk it was addressed to. Returns the new
  /// document id so the caller can open the record it just created.
  Future<String> send({
    required MemoKind kind,
    required String subject,
    required String body,
    required String fromUid,
    required String fromName,
    required String fromRole,
    required String toChannel,
    UploadPayload? attachment,
  }) async {
    if (toChannel == fromRole) {
      throw const MemoException(
        'A memo cannot be addressed to the office that wrote it.',
      );
    }

    final doc = await _col.add(
      Memo(
        id: '',
        kind: kind,
        subject: subject,
        body: body,
        fromName: fromName,
        fromRole: fromRole,
        fromUid: fromUid,
        toChannel: toChannel,
        attachment: attachment,
      ).toMap(),
    );

    // An Iswim announcement is also emailed to the district officer.
    if (kind == MemoKind.announcement && fromRole == 'iswim') {
      await _db.collection('email_log').add({
        'to': 'District Officer',
        'subject': subject,
        'body': body,
        'byName': fromName,
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    await _notifyRecipient(
      toChannel: toChannel,
      title: '${kind.label} from $fromName',
      body: subject,
      memoId: doc.id,
    );
    return doc.id;
  }

  /// The recipient desk opened the memo. A signed memo keeps its final state.
  Future<void> markReceived(String id) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) throw const MemoException('This memo no longer exists.');
    if (data['status'] == MemoStatus.acknowledged.wireName) return;
    if (data['status'] == MemoStatus.received.wireName) return;
    await _col.doc(id).update({
      'status': MemoStatus.received.wireName,
      'receivedAt': FieldValue.serverTimestamp(),
    });
  }

  /// City Hall signs the memo. The drawn signature, the signer and the time
  /// are stored on the memo itself, so reopening it shows the same record.
  Future<void> acknowledge({
    required String id,
    required String byUid,
    required String byName,
    required String signature,
  }) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) throw const MemoException('This memo no longer exists.');
    if (data['status'] == MemoStatus.acknowledged.wireName) {
      throw const MemoException('This memo has already been signed.');
    }
    if (data['toChannel'] != 'cityHall') {
      throw const MemoException('Only City Hall memos are signed at this desk.');
    }

    await _col.doc(id).update({
      'status': MemoStatus.acknowledged.wireName,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedByUid': byUid,
      'acknowledgedByName': byName,
      'acknowledgementSignature': signature,
    });

    final sender = data['fromUid'] as String? ?? '';
    if (sender.isNotEmpty) {
      await _notifications.push(
        userId: sender,
        title: 'Memo signed by City Hall',
        body: '${data['subject'] ?? 'Your memo'} was signed by $byName.',
        type: AppNotificationType.account,
        data: {'kind': 'memo', 'memoId': id},
      );
    }
  }

  /// The author corrects a memo that has not been received yet.
  Future<void> updateContent({
    required String id,
    required String subject,
    required String body,
    UploadPayload? attachment,
  }) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) throw const MemoException('This memo no longer exists.');
    if (data['status'] != null &&
        data['status'] != MemoStatus.sent.wireName) {
      throw const MemoException(
        'This memo has already been received and can no longer be edited.',
      );
    }
    await _col.doc(id).update({
      'subject': subject,
      'body': body,
      'attachment': attachment?.toMap(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notifyRecipient({
    required String toChannel,
    required String title,
    required String body,
    required String memoId,
  }) async {
    final data = {'kind': 'memo', 'memoId': memoId};
    switch (toChannel) {
      case 'iswim':
        await _notifications.notifyIswim(
          title: title,
          body: body,
          type: AppNotificationType.system,
          data: data,
        );
      case 'barangay':
        await _notifications.notifyStaff(
          title: title,
          body: body,
          type: AppNotificationType.system,
          data: data,
        );
      default:
        await _notifications.notifyCityHall(
          title: title,
          body: body,
          type: AppNotificationType.system,
          data: data,
        );
    }
  }

  static int _newestFirst(Memo a, Memo b) {
    final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }
}
