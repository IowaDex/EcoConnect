class LocationRecord {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime recordedAt;
  final int retryCount;

  const LocationRecord({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
    this.retryCount = 0,
  });

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toUtc().millisecondsSinceEpoch,
      'retry_count': retryCount,
    };
  }

  factory LocationRecord.fromDatabase(Map<String, Object?> data) {
    return LocationRecord(
      id: data['id']! as String,
      userId: data['user_id']! as String,
      latitude: (data['latitude']! as num).toDouble(),
      longitude: (data['longitude']! as num).toDouble(),
      accuracy: (data['accuracy']! as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        data['recorded_at']! as int,
        isUtc: true,
      ),
      retryCount: data['retry_count']! as int,
    );
  }
}
