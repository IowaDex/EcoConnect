import 'package:cloud_firestore/cloud_firestore.dart';

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

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A memo, endorsement, announcement or manual request between City Hall,
/// Iswim and the barangay. Text plus an optional photo, nothing printed.
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
    this.photo,
    this.createdAt,
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
  final String? photo;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'kind': kind.wireName,
        'subject': subject,
        'body': body,
        'fromName': fromName,
        'fromRole': fromRole,
        'fromUid': fromUid,
        'toChannel': toChannel,
        if (photo != null) 'photo': photo,
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
        photo: data['photo'] as String?,
        createdAt: _asDate(data['createdAt']),
      );
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

  Stream<List<Memo>> watchForChannel(String channel) => _col
      .where('toChannel', isEqualTo: channel)
      .limit(60)
      .snapshots()
      .map((snap) {
        final memos = snap.docs
            .map((doc) => Memo.fromDoc(doc.id, doc.data()))
            .whereType<Memo>()
            .toList();
        memos.sort((a, b) {
          final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
        return memos;
      });

  Stream<List<EmailLogEntry>> watchEmailLog() => _db
      .collection('email_log')
      .orderBy('sentAt', descending: true)
      .limit(40)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => EmailLogEntry.fromDoc(doc.id, doc.data()))
          .whereType<EmailLogEntry>()
          .toList());

  Future<void> send({
    required MemoKind kind,
    required String subject,
    required String body,
    required String fromUid,
    required String fromName,
    required String fromRole,
    required String toChannel,
    String? photo,
  }) async {
    await _col.add(
      Memo(
        id: '',
        kind: kind,
        subject: subject,
        body: body,
        fromName: fromName,
        fromRole: fromRole,
        fromUid: fromUid,
        toChannel: toChannel,
        photo: photo,
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

    await _notifications.notifyStaff(
      title: '${kind.label} from $fromName',
      body: subject,
      type: AppNotificationType.system,
      data: {'kind': 'memo', 'toChannel': toChannel},
    );
  }
}
