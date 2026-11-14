import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a trip ticket is in its life.
///
/// The order matters: the ticket only moves forward, and each status names the
/// one person who can move it next.
enum TicketStatus {
  issued,
  accepted,
  declined,
  running,
  submitted,
  barangaySigned,
  iswimSigned,
  completed,
  missed,
  cancelled,
  revisionRequired,
  rejected,
}

extension TicketStatusX on TicketStatus {
  String get label => switch (this) {
        TicketStatus.issued => 'Issued by Iswim',
        TicketStatus.accepted => 'Received by driver',
        TicketStatus.declined => 'Declined by driver',
        TicketStatus.running => 'In progress',
        TicketStatus.submitted => 'Awaiting barangay verification',
        TicketStatus.barangaySigned => 'Barangay approved',
        TicketStatus.iswimSigned => 'Iswim verified',
        TicketStatus.completed => 'Completed',
        TicketStatus.missed => 'Missed',
        TicketStatus.cancelled => 'Cancelled',
        TicketStatus.revisionRequired => 'Requires revision',
        TicketStatus.rejected => 'Rejected',
      };

  /// Who the ticket is sitting with right now.
  TicketStatusSigner? get pendingSigner => switch (this) {
        TicketStatus.issued => TicketStatusSigner.driver,
        TicketStatus.submitted => TicketStatusSigner.barangay,
        TicketStatus.barangaySigned => TicketStatusSigner.iswim,
        TicketStatus.iswimSigned => TicketStatusSigner.cityHall,
        TicketStatus.revisionRequired => TicketStatusSigner.driver,
        _ => null,
      };

  bool get isOpen => this != TicketStatus.completed &&
      this != TicketStatus.cancelled &&
      this != TicketStatus.missed &&
      this != TicketStatus.rejected;

  bool get isSigned => this == TicketStatus.completed;

  static TicketStatus fromName(String? name) => TicketStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TicketStatus.issued,
      );
}

/// Everyone who touches a ticket, in the order they sign it.
enum TicketStatusSigner { driver, barangay, iswim, cityHall }

extension TicketStatusSignerX on TicketStatusSigner {
  String get wireName => switch (this) {
        TicketStatusSigner.driver => 'driver',
        TicketStatusSigner.barangay => 'barangay',
        TicketStatusSigner.iswim => 'iswim',
        TicketStatusSigner.cityHall => 'cityHall',
      };

  String get label => switch (this) {
        TicketStatusSigner.driver => 'Driver',
        TicketStatusSigner.barangay => 'Barangay',
        TicketStatusSigner.iswim => 'Iswim',
        TicketStatusSigner.cityHall => 'City Hall',
      };

  /// The signature this hop leaves behind (the driver accepts, not signs).
  bool get isSignature => this != TicketStatusSigner.driver;

  static TicketStatusSigner fromName(String? name) =>
      TicketStatusSigner.values.firstWhere(
        (s) => s.wireName == name,
        orElse: () => TicketStatusSigner.barangay,
      );
}

DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A digital signature on a trip ticket.
///
/// The image is a base64 PNG drawn on the device or an uploaded picture, so
/// nothing is ever printed. A signature can be replaced by its owner; the
/// ticket content cannot change after the first signature.
class TicketSignature {
  const TicketSignature({
    required this.signer,
    required this.name,
    required this.uid,
    this.image,
    this.signedAt,
  });

  final TicketStatusSigner signer;
  final String name;
  final String uid;
  final String? image;
  final DateTime? signedAt;

  bool get isPresent => signedAt != null && (image ?? '').isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'uid': uid,
        if (image != null) 'image': image,
        'signedAt': FieldValue.serverTimestamp(),
      };

  static TicketSignature? fromMap(TicketStatusSigner signer, dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    return TicketSignature(
      signer: signer,
      name: data['name'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      image: data['image'] as String?,
      signedAt: _date(data['signedAt']),
    );
  }
}

/// One immutable entry in the ticket's audit trail.
///
/// Every transition records who did it, when, the previous status, the new
/// status and an optional remark. A rejected or returned ticket therefore
/// keeps its reason instead of overwriting the record.
class TicketHistoryEntry {
  const TicketHistoryEntry({
    required this.status,
    required this.byUid,
    required this.byName,
    this.previousStatus,
    this.note = '',
    this.at,
  });

  final TicketStatus status;
  final TicketStatus? previousStatus;
  final String byUid;
  final String byName;
  final String note;
  final DateTime? at;

  Map<String, dynamic> toMap() => {
        'status': status.name,
        if (previousStatus != null) 'previousStatus': previousStatus!.name,
        'byUid': byUid,
        'byName': byName,
        'note': note,
        // FieldValue is rejected inside an array, so the entry carries a
        // client timestamp while the document keeps server timestamps.
        'at': Timestamp.now(),
      };

  static TicketHistoryEntry? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    return TicketHistoryEntry(
      status: TicketStatusX.fromName(raw['status'] as String?),
      previousStatus: raw['previousStatus'] == null
          ? null
          : TicketStatusX.fromName(raw['previousStatus'] as String?),
      byUid: raw['byUid'] as String? ?? '',
      byName: raw['byName'] as String? ?? '',
      note: raw['note'] as String? ?? '',
      at: _date(raw['at']),
    );
  }
}

/// A trip ticket: the paper the barangay used to hand out, now digital.
///
/// Iswim issues it against one truck and its permanent driver. The driver
/// accepts before he can move, the trip is logged, then it walks up the chain
/// Barangay -> Iswim -> City Hall for three signatures.
class TripTicket {
  const TripTicket({
    required this.id,
    required this.code,
    required this.wave,
    required this.truckId,
    required this.plateNumber,
    required this.wheelers,
    required this.driverId,
    required this.driverName,
    required this.route,
    required this.zone,
    required this.date,
    required this.windowStart,
    required this.windowEnd,
    required this.notes,
    required this.status,
    required this.createdBy,
    this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.submittedAt,
    this.completedAt,
    this.declineReason,
    this.revisionReason,
    this.rejectionReason,
    this.signatures = const {},
    this.history = const [],
  });

  final String id;

  /// `TT-2026-0001`.
  final String code;

  /// 1 for the regular round, 2 for the second wave of the day.
  final int wave;

  final String truckId;
  final String plateNumber;
  final int wheelers;

  final String driverId;
  final String driverName;

  /// Streets covered, typed in by Iswim.
  final String route;
  final String zone;
  final String date;
  final String windowStart;
  final String windowEnd;
  final String notes;

  final TicketStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final String? declineReason;
  final String? revisionReason;
  final String? rejectionReason;

  final Map<TicketStatusSigner, TicketSignature> signatures;
  final List<TicketHistoryEntry> history;

  bool get needsDriver => status == TicketStatus.issued;
  bool get needsRevision => status == TicketStatus.revisionRequired;
  bool get canStartTrip =>
      status == TicketStatus.accepted || status == TicketStatus.running;

  TicketSignature? signatureFor(TicketStatusSigner signer) => signatures[signer];

  /// The next signature the chain expects, or null when the chain is not at a
  /// signing step.
  TicketStatusSigner? get awaitingSignature => switch (status) {
        TicketStatus.submitted => TicketStatusSigner.barangay,
        TicketStatus.barangaySigned => TicketStatusSigner.iswim,
        TicketStatus.iswimSigned => TicketStatusSigner.cityHall,
        _ => null,
      };

  String get waveLabel => 'Wave $wave';

  String get windowLabel => '$windowStart – $windowEnd';

  Map<String, dynamic> toMap() => {
        'code': code,
        'wave': wave,
        'truckId': truckId,
        'plateNumber': plateNumber,
        'wheelers': wheelers,
        'driverId': driverId,
        'driverName': driverName,
        'route': route,
        'zone': zone,
        'date': date,
        'windowStart': windowStart,
        'windowEnd': windowEnd,
        'notes': notes,
        'status': status.name,
        'pendingSigner': status.pendingSigner?.wireName,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'signatures': <String, dynamic>{},
        'history': [
          TicketHistoryEntry(
            status: TicketStatus.issued,
            byUid: createdBy,
            byName: 'Iswim',
            note: 'Trip ticket issued',
          ).toMap(),
        ],
      };

  static TripTicket? fromDoc(String id, Map<String, dynamic> data) {
    final rawSignatures = data['signatures'];
    final signatures = <TicketStatusSigner, TicketSignature>{};
    if (rawSignatures is Map) {
      for (final signer in TicketStatusSigner.values) {
        final parsed = TicketSignature.fromMap(
          signer,
          rawSignatures[signer.wireName],
        );
        if (parsed != null) signatures[signer] = parsed;
      }
    }

    final rawHistory = data['history'];
    final history = rawHistory is List
        ? rawHistory
            .map(TicketHistoryEntry.fromMap)
            .whereType<TicketHistoryEntry>()
            .toList(growable: false)
        : const <TicketHistoryEntry>[];

    return TripTicket(
      id: id,
      code: data['code'] as String? ?? id,
      wave: (data['wave'] as num?)?.toInt() ?? 1,
      truckId: data['truckId'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      wheelers: (data['wheelers'] as num?)?.toInt() ?? 4,
      driverId: data['driverId'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      route: data['route'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
      date: data['date'] as String? ?? '',
      windowStart: data['windowStart'] as String? ?? '',
      windowEnd: data['windowEnd'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      status: TicketStatusX.fromName(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _date(data['createdAt']),
      acceptedAt: _date(data['acceptedAt']),
      startedAt: _date(data['startedAt']),
      submittedAt: _date(data['submittedAt']),
      completedAt: _date(data['completedAt']),
      declineReason: data['declineReason'] as String?,
      revisionReason: data['revisionReason'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      signatures: signatures,
      history: history,
    );
  }
}
