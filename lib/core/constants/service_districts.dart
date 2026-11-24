import 'service_area.dart';

/// The legislative districts of Quezon City, used to assign a District Officer
/// and to route an SOS to the officer who owns the affected area.
///
/// EcoConnect serves one barangay today, so [defaultDistrict] is the district
/// that barangay belongs to. The full list stays available because an SOS may
/// be filed for a neighbouring area that shares the same collection partner.
class ServiceDistricts {
  const ServiceDistricts._();

  static const String defaultDistrict = 'District 2';

  static const List<String> all = [
    'District 1',
    'District 2',
    'District 3',
    'District 4',
    'District 5',
    'District 6',
  ];

  /// The district a barangay belongs to, when it is the one this deployment
  /// serves. Unknown barangays return null so the caller can ask.
  static String? ofBarangay(String? barangay) =>
      ServiceArea.covers(barangay) ? defaultDistrict : null;

  static bool isValid(String? district) =>
      district != null && all.contains(district.trim());

  /// The barangays a district covers, as far as this deployment knows them.
  ///
  /// Only the served barangay is known for certain; the rest are read from the
  /// staff directory at runtime so no barangay names are invented here.
  static List<String> knownBarangays(String? district) {
    if (district == null || district.trim().isEmpty) return const [];
    return district.trim() == defaultDistrict ? const [ServiceArea.barangay] : const [];
  }
}
