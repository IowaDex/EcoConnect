import 'package:eco_connect/core/widgets/eco_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the blocking loader is the truck and nothing else',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EcoLoadingBody(width: 280)),
      ),
    );

    // The truck card is the whole loading state — no tips, no page dots.
    expect(find.byType(EcoTruckCard), findsOneWidget);
    expect(find.byType(EcoTruckArt), findsOneWidget);
    expect(find.text('PRO TIP'), findsNothing);
    expect(find.byType(EcoLoadingDots), findsNothing);
  });

  testWidgets('inline loader shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EcoLoadingView(label: 'Loading requests')),
      ),
    );

    expect(find.text('Loading requests'), findsOneWidget);
    expect(find.byType(EcoTruckArt), findsOneWidget);
  });

  testWidgets('overlay loader keeps the message above the truck',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EcoLoadingOverlay(message: 'Saving your report')),
      ),
    );

    expect(find.text('Saving your report'), findsOneWidget);
    expect(find.byType(EcoTruckArt), findsOneWidget);
  });
}
