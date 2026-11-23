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

  /// A manual-approval ticket that City Hall has signed. The schedule is valid
  /// and the driver can run it.
  valid,
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
    TicketStatus.valid => 'Valid',
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

  bool get isOpen =>
      this != TicketStatus.completed &&
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

/// What a ticket represents.
///
/// [run] is the original per-trip ticket: Iswim issues it, the driver accepts
/// and runs it, then Barangay, Iswim and City Hall sign it.
///
/// [assignment] is the manual ticket introduced for the collection schedule.
/// Iswim builds it from a City Hall manual request (driver, plate, up to three
/// routes, days, start time and recurrence). It is valid only after City Hall
/// approves it; the barangay and residents then read the same schedule.
enum TicketKind { run, assignment }

extension TicketKindX on TicketKind {
  String get wireName => switch (this) {
    TicketKind.run => 'run',
    TicketKind.assignment => 'assignment',
  };

  static TicketKind fromName(String? name) => TicketKind.values.firstWhere(
    (k) => k.wireName == name,
    orElse: () => TicketKind.run,
  );
}

/// How often a manual assignment repeats.
enum ManualRecurrence { weekly, monthly, yearly }

extension ManualRecurrenceX on ManualRecurrence {
  String get label => switch (this) {
    ManualRecurrence.weekly => 'Weekly',
    ManualRecurrence.monthly => 'Monthly',
    ManualRecurrence.yearly => 'Yearly',
  };

  static ManualRecurrence fromName(String? name) => ManualRecurrence.values
      .firstWhere((r) => r.name == name, orElse: () => ManualRecurrence.weekly);
}

/// `1 = Monday … 7 = Sunday`, matching [DateTime.weekday].
const kManualDayNames = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String manualDayLabel(int day) =>
    day >= 1 && day <= 7 ? kManualDayNames[day - 1] : '—';

/// The most areas a truck may be given: one for every two wheels.
///
/// A 4-wheeler covers two areas, a 6-wheeler three, an 8-wheeler four and a
/// 10-wheeler five.
int maxRoutesForWheelers(int wheelers) => wheelers <= 4 ? 2 : wheelers ~/ 2;

/// The shortest gap between two shifts for the same driver, in minutes.
///
/// A crew that starts at 8 AM cannot be sent out again at 10 AM: anything
/// closer than six hours is the same slot. 8 AM and 6 PM are two shifts.
const kManualMinGapMinutes = 6 * 60;

/// An `HH:mm` start time as minutes since midnight.
int manualMinutes(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return hour * 60 + minute;
}

/// Whether two `HH:mm` starts are too close to be two separate shifts.
///
/// Exactly [kManualMinGapMinutes] apart is allowed, so 8 AM and 2 PM pass and
/// 8 AM and 1 PM do not.
bool manualSlotsClash(String a, String b) =>
    (manualMinutes(a) - manualMinutes(b)).abs() < kManualMinGapMinutes;

/// Whether two manual rows are the same driver.
///
/// A row taken from the driver accounts carries a uid; a row typed from the
/// fleet roster only carries a name. The uid decides when both sides have one,
/// otherwise the name does, so the same crew is never booked twice.
bool manualSameDriver({
  required String driverId,
  required String driverName,
  required String otherDriverId,
  required String otherDriverName,
}) {
  if (driverId.isNotEmpty && otherDriverId.isNotEmpty) {
    return driverId == otherDriverId;
  }
  final name = driverName.trim().toLowerCase();
  return name.isNotEmpty && name == otherDriverName.trim().toLowerCase();
}

/// Whether a manual roster puts the crew on duty on [date].
///
/// The recurrence is how long the schedule stays in force, not how often it
/// repeats: the listed weekdays are worked every week, and
/// - weekly runs until it is cancelled,
/// - monthly runs for one month from [createdAt],
/// - yearly runs for one year from [createdAt].
///
/// A manual with no creation date (written before the field existed) is
/// treated as open-ended so its crew is never locked out.
bool manualRunsOn({
  required List<int> days,
  required ManualRecurrence recurrence,
  required DateTime? createdAt,
  required DateTime date,
}) {
  if (!days.contains(date.weekday)) return false;
  if (recurrence == ManualRecurrence.weekly) return true;

  final created = createdAt;
  if (created == null) return true;

  final start = DateTime(created.year, created.month, created.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day.isBefore(start)) return false;

  final end = recurrence == ManualRecurrence.monthly
      ? DateTime(created.year, created.month + 1, created.day)
      : DateTime(created.year + 1, created.month, created.day);
  return day.isBefore(end);
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

/// One street picked on the map: the label and the point that was tapped.
///
/// The name is what the manual prints; the point is what lets the driver's
/// map draw the streets he has to cover without geocoding them again.
class ManualRoutePoint {
  const ManualRoutePoint({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toMap() => {
    'name': name,
    'lat': latitude,
    'lng': longitude,
  };

  static ManualRoutePoint? fromDynamic(dynamic raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] as String?)?.trim() ?? '';
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    if (name.isEmpty || lat == null || lng == null) return null;
    return ManualRoutePoint(name: name, latitude: lat, longitude: lng);
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
    this.kind = TicketKind.run,
    this.routes = const [],
    this.routePoints = const [],
    this.days = const [],
    this.recurrence = ManualRecurrence.weekly,
    this.assignmentId,
    this.approvalPending = false,
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

  /// A plain collection run or a manual assignment.
  final TicketKind kind;

  /// Up to three streets for an assignment. Empty for a [TicketKind.run].
  final List<String> routes;

  /// The map points behind [routes], in the order they were tapped.
  final List<ManualRoutePoint> routePoints;

  /// Days of the week (1 = Mon … 7 = Sun) an assignment runs on.
  final List<int> days;

  /// Weekly, monthly or yearly repeat.
  final ManualRecurrence recurrence;

  /// The `assignment_manuals` record this ticket was generated from.
  final String? assignmentId;

  /// True while the manual ticket is waiting for City Hall's signature.
  final bool approvalPending;

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

  bool get isAssignment => kind == TicketKind.assignment;

  bool get needsDriver => status == TicketStatus.issued && !approvalPending;

  bool get needsRevision => status == TicketStatus.revisionRequired;

  bool get canStartTrip =>
      status == TicketStatus.accepted ||
      status == TicketStatus.running ||
      (isAssignment && status == TicketStatus.valid);

  /// The driver finished the run described by a manual ticket.
  bool get canCompleteAssignment =>
      isAssignment && status == TicketStatus.valid;

  /// Whether the manual puts this crew on duty on [date].
  ///
  /// The recurrence sets how long the roster stays in force (see
  /// [manualRunsOn]); the listed weekdays are worked every week.
  bool runsOn(DateTime date) {
    if (!isAssignment) return true;
    return manualRunsOn(
      days: days,
      recurrence: recurrence,
      createdAt: createdAt,
      date: date,
    );
  }

  /// True when today is one of the manual's collection days.
  bool get isScheduledToday => runsOn(DateTime.now());

  /// The manual's `HH:mm` start time as minutes since midnight.
  int get startMinutes {
    final parts = windowStart.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  /// Whether the crew may start at [at].
  ///
  /// Two gates, in this order: [at] must be a working day for the roster, and
  /// the clock must have reached the manual's start time. A shift with no
  /// start time is open as soon as the day matches.
  bool isShiftOpen(DateTime at) {
    if (!runsOn(at)) return false;
    return at.hour * 60 + at.minute >= startMinutes;
  }

  /// The next day this manual runs, looking up to two months ahead.
  ///
  /// Null when nothing matches — a yearly manual outside its month, or a plain
  /// run ticket that has no roster at all.
  DateTime? get nextRun {
    if (!isAssignment) return null;
    final now = DateTime.now();
    for (var i = 0; i < 60; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (runsOn(day)) return day;
    }
    return null;
  }

  TicketSignature? signatureFor(TicketStatusSigner signer) =>
      signatures[signer];

  /// The next signature the chain expects, or null when the chain is not at a
  /// signing step.
  TicketStatusSigner? get awaitingSignature {
    if (approvalPending) return TicketStatusSigner.cityHall;
    return switch (status) {
      TicketStatus.submitted => TicketStatusSigner.barangay,
      TicketStatus.barangaySigned => TicketStatusSigner.iswim,
      TicketStatus.iswimSigned => TicketStatusSigner.cityHall,
      _ => null,
    };
  }

  String get waveLabel => isAssignment ? 'Manual' : 'Wave $wave';

  String get windowLabel =>
      isAssignment ? windowStart : '$windowStart – $windowEnd';

  /// `Mon, Wed, Fri · 06:00 · Weekly`
  String get scheduleLabel {
    if (!isAssignment) return windowLabel;
    final names = [...days]..sort();
    final dayText = names.map(manualDayLabel).join(', ');
    return '$dayText · $windowStart · ${recurrence.label}';
  }

  /// One line for the routes, used on cards and PDF exports.
  String get routesLabel => routes.isEmpty ? route : routes.join(' · ');

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
    'pendingSigner': approvalPending
        ? TicketStatusSigner.cityHall.wireName
        : status.pendingSigner?.wireName,
    'kind': kind.wireName,
    'routes': routes,
    'routePoints': [for (final point in routePoints) point.toMap()],
    'days': days,
    'recurrence': recurrence.name,
    'approvalPending': approvalPending,
    if (assignmentId != null) 'assignmentId': assignmentId,
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
      kind: TicketKindX.fromName(data['kind'] as String?),
      routes:
          (data['routes'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      routePoints:
          (data['routePoints'] as List?)
              ?.map(ManualRoutePoint.fromDynamic)
              .whereType<ManualRoutePoint>()
              .toList(growable: false) ??
          const [],
      days:
          (data['days'] as List?)
              ?.whereType<num>()
              .map((d) => d.toInt())
              .toList(growable: false) ??
          const [],
      recurrence: ManualRecurrenceX.fromName(data['recurrence'] as String?),
      assignmentId: data['assignmentId'] as String?,
      approvalPending: data['approvalPending'] == true,
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
