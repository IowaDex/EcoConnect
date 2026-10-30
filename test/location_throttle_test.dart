import 'package:eco_connect/features/location/models/location_record.dart';
import 'package:eco_connect/features/location/repositories/location_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);
  final previous = LocationRecord(
    id: 'a',
    userId: 'u',
    latitude: 10,
    longitude: 20,
    accuracy: 5,
    recordedAt: start,
  );
  // About 25 m north of the previous fix.
  const movedLatitude = 10.000225;

  bool shouldSave(double latitude, Duration after) => LocationRepository.shouldSave(
        previous,
        latitude,
        20,
        start.add(after),
      );

  test('saves the first fix', () {
    expect(LocationRepository.shouldSave(null, 10, 20, start), isTrue);
  });

  test('moving fast saves at most every 5 seconds', () {
    expect(shouldSave(movedLatitude, const Duration(seconds: 2)), isFalse);
    expect(shouldSave(movedLatitude, const Duration(seconds: 6)), isTrue);
  });

  test('standing still saves every 30 seconds', () {
    expect(shouldSave(10, const Duration(seconds: 10)), isFalse);
    expect(shouldSave(10, const Duration(seconds: 31)), isTrue);
  });
}
