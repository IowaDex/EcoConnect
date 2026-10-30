import 'dart:async';

import 'package:eco_connect/features/location/models/location_sync_state.dart';
import 'package:eco_connect/features/location/providers/location_provider.dart';
import 'package:eco_connect/features/location/repositories/location_repository.dart';
import 'package:eco_connect/features/location/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Stand-ins for the two collaborators; only the calls LocationProvider makes.
class _FakeRepository extends Fake implements LocationRepository {
  final userChanges = StreamController<String?>.broadcast();
  final calls = <String>[];
  bool removeResult = true;
  Object? syncError;

  @override
  String? currentUserId = 'u1';
  @override
  Stream<String?> get userIdChanges => userChanges.stream;
  @override
  bool sharingEnabled = false;

  @override
  void reset() => calls.add('reset');
  @override
  Future<bool> removeSharedLocation() async {
    calls.add('removeSharedLocation');
    return removeResult;
  }

  @override
  Future<int> pendingCount() async => 1;
  @override
  Future<int> syncPending() async {
    if (syncError != null) throw syncError!;
    return 0;
  }
}

class _FakeService extends Fake implements LocationService {}

void main() {
  late _FakeRepository repository;
  late StreamController<Object?> connectivity;
  late LocationProvider provider;

  setUp(() {
    repository = _FakeRepository();
    connectivity = StreamController<Object?>.broadcast();
    provider = LocationProvider(
      repository: repository,
      service: _FakeService(),
      connectivityChanges: connectivity.stream,
    );
  });

  tearDown(() async {
    provider.dispose();
    await repository.userChanges.close();
    await connectivity.close();
  });

  test('endSession resets, removes the shared pin, then reports the result',
      () async {
    expect(await provider.endSession(), isTrue);
    expect(repository.calls, ['reset', 'removeSharedLocation']);

    repository.removeResult = false;
    expect(await provider.endSession(), isFalse);
  });

  test('a different account clears the previous account state', () async {
    var notified = 0;
    provider.addListener(() => notified++);

    repository.userChanges.add('u1'); // same user: nothing happens
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, isEmpty);

    repository.userChanges.add('u2');
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, ['reset']);
    expect(provider.sharedLocations, isEmpty);
    expect(provider.isSharingLocation, isFalse);
    expect(notified, greaterThan(0));
  });

  test('coming back online syncs; a network failure reads as offline',
      () async {
    repository.syncError = TimeoutException('no network');
    connectivity.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.syncState, LocationSyncState.offline);
    expect(provider.pendingCount, 1);
  });

  test('other sync failures are failed, not offline', () async {
    repository.syncError = StateError('disk full');
    connectivity.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.syncState, LocationSyncState.failed);
  });
}
