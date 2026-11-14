/// A garbage truck a crew can be assigned to.
///
/// The barangay owns the fleet: every truck has a plate number and a body
/// type that tells the crew how much it can carry. [centerLatitude] /
/// [centerLongitude] is the middle of the zone the truck is allowed to cover;
/// the trip guard measures the 100 m radius from it.
class GarbageTruck {
  const GarbageTruck({
    required this.id,
    required this.plateNumber,
    required this.wheelers,
    required this.bodyType,
    required this.barangay,
    required this.zone,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.driverName,
    this.driverAccountId,
  });

  final String id;

  /// Plate as painted on the truck, e.g. `SK 4821`.
  final String plateNumber;

  /// 4, 6 or 8 — how many wheels the truck runs on.
  final int wheelers;

  /// Compactor, dump truck, mini compactor…
  final String bodyType;

  final String barangay;

  /// Zone the truck is assigned to inside the barangay.
  final String zone;

  final double centerLatitude;
  final double centerLongitude;

  /// A truck never sits idle: every plate has a named driver assigned to it.
  final String driverName;

  /// Login of the driver holding this truck. Set when City Hall provisions the
  /// account; the truck still belongs to [driverName] before that.
  final String? driverAccountId;

  /// `8-wheeler` — the wording used on the truck cards.
  String get wheelerLabel => '$wheelers-wheeler';

  /// `8-wheeler compactor` — used in one-line summaries.
  String get description => '$wheelerLabel ${bodyType.toLowerCase()}';

  String get areaLabel => '$barangay · $zone';

  Map<String, dynamic> toMap() => {
        'id': id,
        'plateNumber': plateNumber,
        'wheelers': wheelers,
        'bodyType': bodyType,
        'barangay': barangay,
        'zone': zone,
        'centerLatitude': centerLatitude,
        'centerLongitude': centerLongitude,
        'driverName': driverName,
        if (driverAccountId != null) 'driverAccountId': driverAccountId,
      };

  static GarbageTruck? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final id = data['id'] as String?;
    final plate = data['plateNumber'] as String?;
    final lat = (data['centerLatitude'] as num?)?.toDouble();
    final lng = (data['centerLongitude'] as num?)?.toDouble();
    if (id == null || plate == null || lat == null || lng == null) return null;
    return GarbageTruck(
      id: id,
      plateNumber: plate,
      wheelers: (data['wheelers'] as num?)?.toInt() ?? 4,
      bodyType: data['bodyType'] as String? ?? 'Compactor',
      barangay: data['barangay'] as String? ?? 'Batasan Hills',
      zone: data['zone'] as String? ?? 'Zone 1',
      centerLatitude: lat,
      centerLongitude: lng,
      driverName: data['driverName'] as String? ?? 'Unassigned',
      driverAccountId: data['driverAccountId'] as String?,
    );
  }
}
