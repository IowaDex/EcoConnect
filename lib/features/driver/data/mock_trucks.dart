import '../models/garbage_truck.dart';

/// The barangay fleet, mocked until the admin console can register trucks.
///
/// Ten trucks is what the driver and guide see after signing in: plate number
/// and wheel count is enough for a crew to recognise their own vehicle without
/// reading a roster. Coordinates sit inside Batasan Hills, Quezon City so the
/// 100 m trip radius lands on a real map.
const List<GarbageTruck> kMockTrucks = [
  GarbageTruck(
    id: 'truck-01',
    plateNumber: 'SK 4821',
    wheelers: 8,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 1',
    centerLatitude: 14.6792,
    centerLongitude: 121.0961,
    driverName: 'Ramon Dela Cruz',
  ),
  GarbageTruck(
    id: 'truck-02',
    plateNumber: 'SK 5517',
    wheelers: 6,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 2',
    centerLatitude: 14.6805,
    centerLongitude: 121.0992,
    driverName: 'Joel Santiago',
  ),
  GarbageTruck(
    id: 'truck-03',
    plateNumber: 'SK 8834',
    wheelers: 4,
    bodyType: 'Mini compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 3',
    centerLatitude: 14.6764,
    centerLongitude: 121.0954,
    driverName: 'Mario Bautista',
  ),
  GarbageTruck(
    id: 'truck-04',
    plateNumber: 'SG 2290',
    wheelers: 8,
    bodyType: 'Dump truck',
    barangay: 'Batasan Hills',
    zone: 'Zone 4',
    centerLatitude: 14.6812,
    centerLongitude: 121.0948,
    driverName: 'Ernesto Reyes',
  ),
  GarbageTruck(
    id: 'truck-05',
    plateNumber: 'SG 6104',
    wheelers: 6,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 5',
    centerLatitude: 14.6771,
    centerLongitude: 121.1005,
    driverName: 'Dante Villanueva',
  ),
  GarbageTruck(
    id: 'truck-06',
    plateNumber: 'SH 3372',
    wheelers: 4,
    bodyType: 'Mini compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 6',
    centerLatitude: 14.6752,
    centerLongitude: 121.0977,
    driverName: 'Rolando Cruz',
  ),
  GarbageTruck(
    id: 'truck-07',
    plateNumber: 'SH 9081',
    wheelers: 8,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 7',
    centerLatitude: 14.6828,
    centerLongitude: 121.0989,
    driverName: 'Bienvenido Santos',
  ),
  GarbageTruck(
    id: 'truck-08',
    plateNumber: 'SJ 1156',
    wheelers: 6,
    bodyType: 'Dump truck',
    barangay: 'Batasan Hills',
    zone: 'Zone 8',
    centerLatitude: 14.6739,
    centerLongitude: 121.0931,
    driverName: 'Alfredo Mendoza',
  ),
  GarbageTruck(
    id: 'truck-09',
    plateNumber: 'SJ 6640',
    wheelers: 4,
    bodyType: 'Mini compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 9',
    centerLatitude: 14.6801,
    centerLongitude: 121.1022,
    driverName: 'Nestor Aquino',
  ),
  GarbageTruck(
    id: 'truck-10',
    plateNumber: 'SL 7723',
    wheelers: 8,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 10',
    centerLatitude: 14.6748,
    centerLongitude: 121.1013,
    driverName: 'Ruben Domingo',
  ),
];

/// The truck a driver is assigned to.
///
/// A driver never picks a plate: the pairing is fixed by Iswim and the account
/// is provisioned by City Hall. [assignedTruckId] wins; when the account has
/// not been linked yet the driver's name is matched against the roster, and as
/// a last resort the uid picks a stable plate so no driver is ever left
/// without a truck.
GarbageTruck? truckForDriver({
  String? assignedTruckId,
  String? driverName,
  String? uid,
}) {
  final direct = truckById(assignedTruckId);
  if (direct != null) return direct;

  final name = (driverName ?? '').trim().toLowerCase();
  if (name.isNotEmpty) {
    for (final truck in kMockTrucks) {
      if (truck.driverName.toLowerCase() == name) return truck;
    }
  }

  if (uid == null || uid.isEmpty) return null;
  final index = uid.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
      kMockTrucks.length;
  return kMockTrucks[index];
}

/// Looks a truck up by id, e.g. when restoring the last choice from storage.
GarbageTruck? truckById(String? id) {
  if (id == null) return null;
  for (final truck in kMockTrucks) {
    if (truck.id == id) return truck;
  }
  return null;
}
