import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/models/shared_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> valid() => {
        'displayName': 'Dana',
        'role': 'driver',
        'latitude': 10,
        'longitude': 20.5,
        'accuracy': 4,
        'recordedAt': Timestamp.fromMillisecondsSinceEpoch(0),
      };

  test('parses a valid document', () {
    final location = SharedLocation.tryParse('u1', valid());
    expect(location, isNotNull);
    expect(location!.userId, 'u1');
    expect(location.latitude, 10.0);
    expect(location.role, 'driver');
  });

  test('skips malformed documents instead of throwing', () {
    expect(SharedLocation.tryParse('u1', valid()..['latitude'] = 'abc'), isNull);
    expect(SharedLocation.tryParse('u1', valid()..remove('recordedAt')), isNull);
    expect(SharedLocation.tryParse('u1', null), isNull);
  });
}
