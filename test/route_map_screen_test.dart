import 'dart:convert';

import 'package:eco_connect/features/route/models/route_plan.dart';
import 'package:eco_connect/features/route/screens/route_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 1x1 transparent PNG so the map never touches the tile server in tests.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _BlankTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

void main() {
  testWidgets('route map renders stops and the details panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouteMapScreen(
          title: 'Your route map',
          tileProvider: _BlankTileProvider(),
          stops: const [
            RouteStop(name: 'Stop 1', latitude: 14.6, longitude: 121.0),
            RouteStop(name: 'Stop 2', latitude: 14.61, longitude: 121.01),
          ],
          truck: const LatLng(14.605, 121.005),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Your route map'), findsOneWidget);
    expect(find.text('Stop 1'), findsWidgets);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('route map shows an empty state without stops', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteMapScreen(title: 'Your route map', stops: []),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No pinned stops'), findsOneWidget);
  });
}
