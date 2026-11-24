import 'package:latlong2/latlong.dart';

import '../../../core/constants/resident_areas.dart';

/// One subdivision, village or sitio a manual can send a truck through.
///
/// The name is what the manual prints and what the routes checklist shows.
/// [center] is where that place actually is in the barangay.
class ManualArea {
  const ManualArea({required this.name, required this.center});

  final String name;
  final LatLng center;
}

/// Where each area is, looked up in OpenStreetMap by its own name.
///
/// The list follows [ResidentAreas.all] so the sign-up picker and the manual
/// desk always speak about the same places. Each coordinate is the mapped
/// centre of that subdivision — Kalayaan A sits on Kalayaan A, Northview 1 on
/// Northview 1 — instead of a point on a grid, which put several badges on the
/// wrong side of the barangay.
final List<ManualArea> kManualAreas = _buildAreas();

/// A few of the barangay's areas have no mapped outline, so their pin is the
/// middle of the block they are known to sit in, next to the areas around
/// them. Those rows are marked `approx` below.
const Map<String, LatLng> _pins = {
  'Filinvest 1': LatLng(14.6814635, 121.0923142),
  'Filinvest 2': LatLng(14.6894628, 121.0977644),
  'Filinvest Heights': LatLng(14.6848000, 121.0934000), // approx
  'Northview 1': LatLng(14.6795643, 121.1060192),
  'Northview 2': LatLng(14.6840937, 121.1084228),
  'Northview Villas': LatLng(14.6825031, 121.1036076),
  'Vista Real Executive Village': LatLng(14.6747081, 121.0917638),
  'Vista Real Classica': LatLng(14.6757331, 121.1026148),
  'Ciudad Regina': LatLng(14.6848023, 121.0943001),
  'Luzviminda Village': LatLng(14.6853731, 121.0928901),
  'Sugartowne': LatLng(14.6924485, 121.1010790),
  'Sugartowne Homes': LatLng(14.6933000, 121.1022000), // approx
  'Sunnyside Heights': LatLng(14.6884492, 121.1025863),
  'Spring Country': LatLng(14.6866000, 121.0955000), // approx
  'Capitol Ridge': LatLng(14.6905072, 121.1002149),
  'New Capitol Estates': LatLng(14.6805668, 121.0868834),
  'Capitol Bliss': LatLng(14.6909000, 121.1014000), // approx
  'Villa Amor Uno': LatLng(14.6872416, 121.1044139),
  'Doña Pilar': LatLng(14.6826424, 121.0911624),
  'Doña Ana': LatLng(14.6842659, 121.1055037),
  'Doña Juana': LatLng(14.6834000, 121.0930000), // approx
  'Tivoli Royale': LatLng(14.6772803, 121.0947137),
  'Tivoli Greens': LatLng(14.6763551, 121.0903423),
  // Violago Homes and Constitution Hills sit on the northern line, where the
  // barangay steps down; their pins stay just inside it.
  'Violago Homes': LatLng(14.6974000, 121.1004000),
  'Nelson Ville I': LatLng(14.6881788, 121.0999994),
  'Garland': LatLng(14.6797658, 121.1034198),
  'Sierra Monte': LatLng(14.6881200, 121.1102693),
  'Talanay': LatLng(14.6803942, 121.0984205),
  'Talanay Area B': LatLng(14.6832000, 121.0986000), // approx
  'Talanay Area C': LatLng(14.6809638, 121.0965684),
  'Sitio Taniman': LatLng(14.6781940, 121.0997620),
  'Sitio Kaliwa': LatLng(14.6902864, 121.0983816),
  'Shelter Homes': LatLng(14.6897912, 121.0998609),
  'Kalayaan A': LatLng(14.6899858, 121.0890183),
  'Kalayaan B': LatLng(14.6915576, 121.0886183),
  'Kalayaan C': LatLng(14.6924855, 121.0878688),
  'Constitution Hills': LatLng(14.6974000, 121.0996000), // approx
};

List<ManualArea> _buildAreas() {
  final names = [
    for (final name in ResidentAreas.all)
      if (!ResidentAreas.isOther(name)) name,
  ];
  assert(
    names.every(_pins.containsKey),
    'Every resident area needs a map pin before it can be scheduled.',
  );
  return List<ManualArea>.unmodifiable([
    for (final name in names)
      ManualArea(
        name: name,
        center: _pins[name] ?? const LatLng(14.6863, 121.0993),
      ),
  ]);
}

/// The area with this name, or null when the record holds an older free-text
/// route that is not one of the barangay's listed areas.
ManualArea? manualAreaByName(String name) {
  final needle = name.trim().toLowerCase();
  for (final area in kManualAreas) {
    if (area.name.toLowerCase() == needle) return area;
  }
  return null;
}

/// The areas behind a list of names, in the order the names were given.
List<ManualArea> manualAreasFor(Iterable<String> names) => [
  for (final name in names)
    if (manualAreaByName(name) case final area?) area,
];
