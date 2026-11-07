import 'package:eco_connect/core/widgets/eco_loading.dart';
import 'package:eco_connect/features/splash/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash renders the truck panel and a rotating tip',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PRO TIP'), findsOneWidget);
    expect(find.textContaining('Rinse your recyclables'), findsOneWidget);
    expect(find.text('Preparing your barangay feed'), findsOneWidget);

    // Dispose the timers and controllers before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tips rotate while the app waits', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcoTipCard(interval: Duration(milliseconds: 600)),
        ),
      ),
    );

    expect(find.textContaining('Rinse your recyclables'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Flatten boxes'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inline loader shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EcoLoadingView(label: 'Loading requests')),
      ),
    );

    expect(find.text('Loading requests'), findsOneWidget);
  });
}
