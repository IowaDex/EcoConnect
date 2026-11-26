import '../../tickets/models/trip_ticket.dart';

/// One driver's row inside a collection manual.
///
/// A manual is a bulk assignment: City Hall asks for a schedule, and Iswim
/// puts several drivers on it at once. Each row carries its own plate, areas,
/// days, start time and recurrence, and generates its own trip ticket.
class ManualAssignment {
  const ManualAssignment({
    required this.driverId,
    required this.driverName,
    required this.truckId,
    required this.plateNumber,
    required this.wheelers,
    required this.routes,
    required this.days,
    required this.startTime,
    required this.recurrence,
    this.routePoints = const [],
    this.dayRoutes = const {},
  });

  final String driverId;
  final String driverName;

  final String truckId;
  final String plateNumber;
  final int wheelers;

  /// Area names, up to [maxRoutes]. When [dayRoutes] is set this is the union
  /// of every day, so lists and the PDF still show the whole run.
  final List<String> routes;

  /// The pins behind [routes], so the driver's map can draw the same run.
  final List<ManualRoutePoint> routePoints;

  /// 1 = Monday … 7 = Sunday.
  final List<int> days;

  /// `HH:mm`, 24-hour clock.
  final String startTime;

  final ManualRecurrence recurrence;

  /// Different areas for different weekdays, e.g. Mon/Wed on Filinvest 1 and
  /// Tue/Thu on Northview. Empty means [routes] is used every day, which is
  /// how every manual written before this field behaves.
  final Map<int, List<String>> dayRoutes;

  int get maxRoutes => maxRoutesForWheelers(wheelers);

  /// Stable within a manual: the driver account when there is one, otherwise
  /// the plate and start time.
  String get key => driverId.isNotEmpty ? driverId : '$plateNumber@$startTime';

  /// The areas this crew covers on [day] (1 = Monday … 7 = Sunday).
  List<String> routesForDay(int day) {
    final specific = dayRoutes[day];
    if (specific != null && specific.isNotEmpty) return specific;
    return routes;
  }

  bool get hasDayRoutes =>
      dayRoutes.values.any((names) => names.isNotEmpty);

  String get routesLabel => routes.join(' · ');

  /// `Mon: Filinvest 1 · Tue: Northview 1`, or the plain list when every day
  /// carries the same areas.
  String get dayRoutesLabel {
    if (!hasDayRoutes) return routesLabel;
    final sorted = [...days]..sort();
    return [
      for (final day in sorted)
        '${manualDayLabel(day)}: ${routesForDay(day).join(', ')}',
    ].join(' · ');
  }

  String get scheduleLabel =>
      '${([...days]..sort()).map(manualDayLabel).join(', ')} · $startTime · '
      '${recurrence.label}';

  Map<String, dynamic> toMap() => {
    'driverId': driverId,
    'driverName': driverName,
    'truckId': truckId,
    'plateNumber': plateNumber,
    'wheelers': wheelers,
    'routes': routes,
    'routePoints': [for (final point in routePoints) point.toMap()],
    'days': days,
    'startTime': startTime,
    'recurrence': recurrence.name,
    if (dayRoutes.isNotEmpty)
      'dayRoutes': {
        for (final entry in dayRoutes.entries)
          '${entry.key}': entry.value,
      },
  };

  static ManualAssignment? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final driverName = (raw['driverName'] as String?)?.trim() ?? '';
    final plate = (raw['plateNumber'] as String?)?.trim() ?? '';
    if (driverName.isEmpty && plate.isEmpty) return null;
    return ManualAssignment(
      driverId: raw['driverId'] as String? ?? '',
      driverName: driverName.isEmpty ? 'Driver' : driverName,
      truckId: raw['truckId'] as String? ?? '',
      plateNumber: plate,
      wheelers: (raw['wheelers'] as num?)?.toInt() ?? 4,
      routes:
          (raw['routes'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      routePoints:
          (raw['routePoints'] as List?)
              ?.map(ManualRoutePoint.fromDynamic)
              .whereType<ManualRoutePoint>()
              .toList(growable: false) ??
          const [],
      days:
          (raw['days'] as List?)
              ?.whereType<num>()
              .map((day) => day.toInt())
              .toList(growable: false) ??
          const [],
      startTime: raw['startTime'] as String? ?? '06:00',
      recurrence: ManualRecurrenceX.fromName(raw['recurrence'] as String?),
      dayRoutes: _parseDayRoutes(raw['dayRoutes']),
    );
  }

  /// `{1: [Filinvest 1], 3: [Filinvest 1]}` from Firestore's string keys.
  static Map<int, List<String>> _parseDayRoutes(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, List<String>>{};
    raw.forEach((key, value) {
      final day = int.tryParse('$key');
      if (day == null || day < 1 || day > 7) return;
      final names =
          (value as List?)?.whereType<String>().toList(growable: false) ??
          const <String>[];
      if (names.isNotEmpty) out[day] = names;
    });
    return out;
  }

  static List<ManualAssignment> listFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(ManualAssignment.fromMap)
        .whereType<ManualAssignment>()
        .toList(growable: false);
  }
}
