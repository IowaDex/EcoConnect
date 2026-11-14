import 'package:eco_connect/features/driver/models/garbage_truck.dart';
import 'package:eco_connect/features/driver/models/truck_status.dart';
import 'package:eco_connect/features/driver/widgets/truck_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _truck = GarbageTruck(
  id: 'truck-01',
  plateNumber: 'SK 4821',
  wheelers: 8,
  bodyType: 'Compactor',
  barangay: 'Batasan Hills',
  zone: 'Zone 1',
  centerLatitude: 14.6792,
  centerLongitude: 121.0961,
  driverName: 'Ramon Dela Cruz',
);

const _parked = GarbageTruck(
  id: 'truck-02',
  plateNumber: 'SK 5517',
  wheelers: 6,
  bodyType: 'Compactor',
  barangay: 'Batasan Hills',
  zone: 'Zone 2',
  centerLatitude: 14.6805,
  centerLongitude: 121.0992,
  driverName: '  ',
);

void main() {
  group('TruckStatusX.resolve', () {
    test('a truck on the move outranks its paperwork', () {
      expect(
        TruckStatusX.resolve(
          truck: _truck,
          inTransit: true,
          hasTicket: true,
        ),
        TruckStatus.inTransit,
      );
    });

    test('a ticket makes a driven truck ready', () {
      expect(
        TruckStatusX.resolve(
          truck: _truck,
          inTransit: false,
          hasTicket: true,
        ),
        TruckStatus.ticketReady,
      );
    });

    test('a driven truck without a ticket is waiting on Iswim', () {
      expect(
        TruckStatusX.resolve(
          truck: _truck,
          inTransit: false,
          hasTicket: false,
        ),
        TruckStatus.noTicket,
      );
    });

    test('a plate nobody drives is inactive, ticket or not', () {
      expect(
        TruckStatusX.resolve(
          truck: _parked,
          inTransit: false,
          hasTicket: false,
        ),
        TruckStatus.inactive,
      );
    });

    test('a blank driver name counts as no driver', () {
      expect(_parked.hasDriver, isFalse);
      expect(_truck.hasDriver, isTrue);
    });
  });

  testWidgets('the card names the status under the zone', (tester) async {
    for (final status in TruckStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruckCard(
              truck: _truck,
              selected: false,
              status: status,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('SK 4821'), findsOneWidget);
      expect(find.text('Batasan Hills · Zone 1'), findsOneWidget);
      expect(find.text(status.label), findsOneWidget);
    }
  });

  testWidgets('tapping a card opens that truck', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TruckCard(
            truck: _truck,
            selected: false,
            status: TruckStatus.noTicket,
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TruckCard));
    expect(tapped, 1);
  });
}
