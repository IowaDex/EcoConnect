import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One place returned by the OpenStreetMap geocoder.
class GeocodeResult {
  const GeocodeResult({required this.displayName, required this.point});

  final String displayName;
  final LatLng point;

  /// First two comma-separated parts keep the label readable in a list.
  String get shortName {
    final parts = displayName.split(',').map((p) => p.trim()).toList();
    if (parts.length <= 2) return displayName;
    return '${parts[0]}, ${parts[1]}';
  }
}

/// Free-text place lookup backed by Nominatim (OpenStreetMap).
///
/// Used by staff route planning so a zone or barangay can be typed and the
/// map can jump straight to it instead of panning by hand.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  factory GeocodingService() => instance;

  Future<List<GeocodeResult>> search(String query, {int limit = 6}) async {
    final text = query.trim();
    if (text.isEmpty) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': text,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '0',
    });

    final response = await http.get(
      uri,
      headers: const {
        // Nominatim asks every client to identify itself.
        'User-Agent': 'EcoConnect/1.0 (barangay waste collection app)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Location search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    final results = <GeocodeResult>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) continue;
      results.add(
        GeocodeResult(
          displayName: (item['display_name'] as String?) ?? text,
          point: LatLng(lat, lon),
        ),
      );
    }
    return results;
  }
}
