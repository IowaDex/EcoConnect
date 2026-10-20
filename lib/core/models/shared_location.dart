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

  factory SharedLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    final timestamp = data['recordedAt'] as Timestamp?;
    if (timestamp == null) {
      throw StateError('Shared location ${snapshot.id} has no recordedAt');
    }
    return SharedLocation(
      userId: snapshot.id,
      displayName: data['displayName'] as String? ?? 'EcoConnect user',
      role: data['role'] as String? ?? 'user',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      accuracy: (data['accuracy'] as num).toDouble(),
      recordedAt: timestamp.toDate(),
    );
  }
}
