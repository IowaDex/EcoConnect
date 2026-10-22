import 'package:cloud_firestore/cloud_firestore.dart';

class SharedLocation {
  final String userId;
  final String displayName;
  final String role;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime recordedAt;

  const SharedLocation({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
  });

  /// Returns null for malformed documents so one bad entry can't break the map.
  static SharedLocation? tryParse(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final timestamp = data['recordedAt'];
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final accuracy = data['accuracy'];
    if (timestamp is! Timestamp ||
        latitude is! num ||
        longitude is! num ||
        accuracy is! num) {
      return null;
    }
    final displayName = data['displayName'];
    final role = data['role'];
    return SharedLocation(
      userId: id,
      displayName: displayName is String ? displayName : 'EcoConnect user',
      role: role is String ? role : 'user',
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: accuracy.toDouble(),
      recordedAt: timestamp.toDate(),
    );
  }
}
