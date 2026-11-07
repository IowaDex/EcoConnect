import 'package:eco_connect/features/landing/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('landing page shows the brand promise and entry points',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(
      find.text(
        'Connecting Communities for a Cleaner and Greener Tomorrow',
      ),
      findsOneWidget,
    );
    expect(find.text('Smarter waste collection\nfor every barangay'),
        findsOneWidget);

    // Dispose the animation controllers so no ticker survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
