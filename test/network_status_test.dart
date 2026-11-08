import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_connect/core/network/network_status.dart';

void main() {
  group('NetworkStatus.isOfflineResult', () {
    test('treats a none-only list as offline', () {
      expect(NetworkStatus.isOfflineResult([ConnectivityResult.none]), isTrue);
    });

    test('treats wifi or mobile as online', () {
      expect(NetworkStatus.isOfflineResult([ConnectivityResult.wifi]), isFalse);
      expect(
        NetworkStatus.isOfflineResult([
          ConnectivityResult.none,
          ConnectivityResult.mobile,
        ]),
        isFalse,
      );
    });

    test('treats an empty or missing reading as online', () {
      expect(NetworkStatus.isOfflineResult(const []), isFalse);
      expect(NetworkStatus.isOfflineResult(null), isFalse);
    });

    test('accepts a bare result from older plugin versions', () {
      expect(NetworkStatus.isOfflineResult(ConnectivityResult.none), isTrue);
      expect(NetworkStatus.isOfflineResult(ConnectivityResult.wifi), isFalse);
    });
  });

  group('NetworkStatus', () {
    test('waits out the grace period before reporting an outage', () async {
      final changes = StreamController<Object?>.broadcast();
      final status = NetworkStatus(
        changes: changes.stream,
        check: () async => [ConnectivityResult.wifi],
        grace: const Duration(milliseconds: 40),
      );
      await status.start();
      addTearDown(() async {
        status.dispose();
        await changes.close();
      });

      changes.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.isOffline, isFalse, reason: 'still inside the grace period');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(status.isOffline, isTrue);
    });

    test('recovers immediately when the link comes back', () async {
      final changes = StreamController<Object?>.broadcast();
      final status = NetworkStatus(
        changes: changes.stream,
        check: () async => [ConnectivityResult.none],
        grace: const Duration(milliseconds: 10),
      );
      await status.start();
      addTearDown(() async {
        status.dispose();
        await changes.close();
      });

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(status.isOffline, isTrue);

      changes.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(status.isOffline, isFalse);
    });

    test('refresh() applies the current link without waiting', () async {
      var result = <ConnectivityResult>[ConnectivityResult.none];
      final status = NetworkStatus(
        changes: const Stream<Object?>.empty(),
        check: () async => result,
        grace: const Duration(seconds: 30),
      );
      await status.start();
      addTearDown(status.dispose);

      // Seeded offline, but the grace timer has not fired yet.
      expect(status.isOffline, isFalse);

      await status.refresh();
      expect(status.isOffline, isTrue);

      result = [ConnectivityResult.wifi];
      await status.refresh();
      expect(status.isOffline, isFalse);
    });

    test('a missing plugin never reports an outage', () async {
      final status = NetworkStatus(
        changes: const Stream<Object?>.empty(),
        check: () async => throw StateError('no plugin'),
        grace: const Duration(milliseconds: 5),
      );
      await status.start();
      addTearDown(status.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(status.isOffline, isFalse);
    });
  });
}
