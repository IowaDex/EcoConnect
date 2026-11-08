import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eco_connect/core/network/network_status.dart';
import 'package:eco_connect/core/widgets/eco_loading.dart';
import 'package:eco_connect/core/widgets/offline_gate.dart';

Widget _host(NetworkStatus? status, {bool enabled = true}) {
  const child = Scaffold(body: Center(child: Text('app content')));
  final gate = OfflineGate(enabled: enabled, child: child);
  return MaterialApp(
    home: status == null
        ? gate
        : ChangeNotifierProvider<NetworkStatus>.value(
            value: status,
            child: gate,
          ),
  );
}

/// A status whose reading the test can flip. `refresh()` applies the new
/// reading immediately, so no timer sits between the change and the assert.
({NetworkStatus status, void Function(bool) setOnline}) _controllable() {
  var online = true;
  final status = NetworkStatus(
    changes: const Stream<Object?>.empty(),
    check: () async => [
      online ? ConnectivityResult.wifi : ConnectivityResult.none,
    ],
    grace: const Duration(milliseconds: 1),
  );
  return (
    status: status,
    setOnline: (value) => online = value,
  );
}

void main() {
  testWidgets('shows the truck when the link is down', (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status));
    expect(find.text('No internet connection'), findsNothing);

    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.byType(EcoTruckArt), findsOneWidget);
    expect(
      find.text('app content'),
      findsOneWidget,
      reason: 'the app stays mounted behind the offline card',
    );
  });

  testWidgets('can be switched off so a driver keeps working offline',
      (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status, enabled: false));
    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(status.isOffline, isTrue);
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  testWidgets('"Keep using saved data" lets the user past the card for this outage',
      (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status));
    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200)); // retry row reveals
    await tester.pump(); // the reveal timer fired; build the new row
    await tester.pump(const Duration(milliseconds: 400)); // let it finish growing
    expect(find.text('No internet connection'), findsOneWidget);

    await tester.tap(find.text('Keep using saved data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('app content'), findsOneWidget);

    // Back online, then offline again: the card returns.
    harness.setOnline(true);
    await tester.runAsync(status.refresh);
    await tester.pump();
    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No internet connection'), findsOneWidget);
  });

  testWidgets('stays out of the way while online', (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  testWidgets('the card lifts again as soon as the link returns',
      (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status));
    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No internet connection'), findsOneWidget);

    harness.setOnline(true);
    await tester.runAsync(status.refresh);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  testWidgets('a missing provider means online, not a crash', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('app content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a retry once the outage settles', (tester) async {
    final harness = _controllable();
    final status = harness.status;
    await tester.runAsync(status.start);
    addTearDown(status.dispose);

    await tester.pumpWidget(_host(status));
    harness.setOnline(false);
    await tester.runAsync(status.refresh);
    await tester.pump();
    expect(find.text('Try again'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('Try again'), findsOneWidget);
  });
}
