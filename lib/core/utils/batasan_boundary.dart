import 'package:latlong2/latlong.dart';

/// The administrative boundary of Barangay Batasan Hills, Quezon City.
///
/// Traced from the barangay's own satellite sheet — the QC Planning location
/// map, where the boundary is drawn as a cyan dashed line. OpenStreetMap's
/// relation 1762720 is close on the east and south but cuts a straight chord
/// across the north and the western subdivisions, which put Filinvest and
/// Northview outside the outline. This ring follows the drawn boundary, so
/// every subdivision the barangay serves is inside it.
///
/// Drawn as a border around the served area, and punched out of the dim
/// overlay that covers everything else.
const List<LatLng> batasanHillsBoundary = <LatLng>[
  LatLng(14.6991731, 121.1025412),
  LatLng(14.6985626, 121.1022112),
  LatLng(14.6985305, 121.1020132),
  LatLng(14.6978235, 121.1016831),
  LatLng(14.6977271, 121.0978548),
  LatLng(14.6972130, 121.0975907),
  LatLng(14.6970523, 121.0972607),
  LatLng(14.6968274, 121.0972607),
  LatLng(14.6957670, 121.0959736),
  LatLng(14.6954135, 121.0958416),
  LatLng(14.6953814, 121.0944224),
  LatLng(14.6951886, 121.0940264),
  LatLng(14.6948351, 121.0938944),
  LatLng(14.6945459, 121.0933663),
  LatLng(14.6941924, 121.0932343),
  LatLng(14.6937425, 121.0926402),
  LatLng(14.6935176, 121.0903300),
  LatLng(14.6929713, 121.0900660),
  LatLng(14.6928428, 121.0895049),
  LatLng(14.6928107, 121.0873597),
  LatLng(14.6880549, 121.0873597),
  LatLng(14.6858055, 121.0870957),
  LatLng(14.6846166, 121.0866336),
  LatLng(14.6843274, 121.0863696),
  LatLng(14.6837490, 121.0862376),
  LatLng(14.6834919, 121.0859736),
  LatLng(14.6812747, 121.0851815),
  LatLng(14.6809855, 121.0849175),
  LatLng(14.6803107, 121.0847854),
  LatLng(14.6792502, 121.0841914),
  LatLng(14.6771937, 121.0833663),
  LatLng(14.6770009, 121.0836633),
  LatLng(14.6768402, 121.0836633),
  LatLng(14.6767438, 121.0861716),
  LatLng(14.6763261, 121.0863696),
  LatLng(14.6762939, 121.0866336),
  LatLng(14.6759083, 121.0870297),
  LatLng(14.6756834, 121.0870297),
  LatLng(14.6756513, 121.0872277),
  LatLng(14.6748479, 121.0874257),
  LatLng(14.6743659, 121.0877557),
  LatLng(14.6739482, 121.0877557),
  LatLng(14.6737875, 121.0881518),
  LatLng(14.6735626, 121.0881518),
  LatLng(14.6733377, 121.0917491),
  LatLng(14.6727271, 121.0944224),
  LatLng(14.6726950, 121.0965676),
  LatLng(14.6716667, 121.0961386),
  LatLng(14.6715382, 121.0964026),
  LatLng(14.6708634, 121.0964026),
  LatLng(14.6705420, 121.0962376),
  LatLng(14.6698993, 121.0967326),
  LatLng(14.6697708, 121.0971287),
  LatLng(14.6695137, 121.0971947),
  LatLng(14.6694816, 121.0987458),
  LatLng(14.6689353, 121.0988449),
  LatLng(14.6698993, 121.0997689),
  LatLng(14.6704778, 121.1008250),
  LatLng(14.6708634, 121.1011551),
  LatLng(14.6709919, 121.1015181),
  LatLng(14.6714739, 121.1018812),
  LatLng(14.6716346, 121.1022442),
  LatLng(14.6720523, 121.1025412),
  LatLng(14.6722130, 121.1029703),
  LatLng(14.6724058, 121.1029703),
  LatLng(14.6728235, 121.1033333),
  LatLng(14.6728556, 121.1035643),
  LatLng(14.6731448, 121.1035973),
  LatLng(14.6742374, 121.1046534),
  LatLng(14.6747515, 121.1053135),
  LatLng(14.6747837, 121.1056765),
  LatLng(14.6750086, 121.1056765),
  LatLng(14.6753621, 121.1064026),
  LatLng(14.6759083, 121.1068316),
  LatLng(14.6759405, 121.1070627),
  LatLng(14.6764225, 121.1071947),
  LatLng(14.6767117, 121.1075247),
  LatLng(14.6770009, 121.1075247),
  LatLng(14.6774829, 121.1079868),
  LatLng(14.6779649, 121.1081188),
  LatLng(14.6782541, 121.1085148),
  LatLng(14.6785112, 121.1085148),
  LatLng(14.6790253, 121.1089769),
  LatLng(14.6802143, 121.1093069),
  LatLng(14.6806641, 121.1096369),
  LatLng(14.6806963, 121.1098350),
  LatLng(14.6812747, 121.1100330),
  LatLng(14.6814675, 121.1102970),
  LatLng(14.6817567, 121.1102970),
  LatLng(14.6823029, 121.1107590),
  LatLng(14.6838454, 121.1114521),
  LatLng(14.6861269, 121.1112211),
  LatLng(14.6882155, 121.1106270),
  LatLng(14.6906577, 121.1105610),
  LatLng(14.6918466, 121.1107260),
  LatLng(14.6920716, 121.1085148),
  LatLng(14.6925536, 121.1084488),
  LatLng(14.6929392, 121.1080528),
  LatLng(14.6931963, 121.1080528),
  LatLng(14.6934212, 121.1072607),
  LatLng(14.6936461, 121.1072607),
  LatLng(14.6938711, 121.1067326),
  LatLng(14.6942245, 121.1066006),
  LatLng(14.6942567, 121.1064026),
  LatLng(14.6948029, 121.1064026),
  LatLng(14.6952207, 121.1066666),
  LatLng(14.6958312, 121.1066996),
  LatLng(14.6965060, 121.1036963),
  LatLng(14.6972451, 121.1036633),
  LatLng(14.6985947, 121.1039604),
  LatLng(14.6991089, 121.1030363),
  LatLng(14.6991731, 121.1026402),
];

/// Whether [point] falls inside the barangay outline.
///
/// Ray casting: count how many edges a ray heading east from the point crosses.
/// Odd means inside. Used to keep map pins, stops and reports on the barangay's
/// own ground instead of guessing from a bounding box.
bool isInsideBatasanHills(LatLng point) {
  var inside = false;
  for (var i = 0, j = batasanHillsBoundary.length - 1;
      i < batasanHillsBoundary.length;
      j = i++) {
    final a = batasanHillsBoundary[i];
    final b = batasanHillsBoundary[j];
    if ((a.latitude > point.latitude) == (b.latitude > point.latitude)) {
      continue;
    }
    final crossing =
        (b.longitude - a.longitude) *
            (point.latitude - a.latitude) /
            (b.latitude - a.latitude) +
        a.longitude;
    if (point.longitude < crossing) inside = !inside;
  }
  return inside;
}
