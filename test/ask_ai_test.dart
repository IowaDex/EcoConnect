import 'package:eco_connect/core/theme/app_theme.dart';
import 'package:eco_connect/features/ai/screens/ask_ai_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The assistant is the one screen every role can reach, so it has to lay out
/// on a phone without a single overflow.
void main() {
  group('ask ai', () {
    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const AskAiScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the topics it can actually answer', (tester) async {
      await pump(tester, const Size(390, 844));

      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('What I can help with'), findsOneWidget);
      for (final topic in const [
        'Collection day',
        'Missed pickup',
        'Recycling',
        'Segregation',
        'Track the truck',
        'My account',
      ]) {
        expect(find.text(topic), findsOneWidget, reason: 'missing $topic');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a topic starts the conversation and swaps in the chips', (
      tester,
    ) async {
      await pump(tester, const Size(390, 844));

      await tester.tap(find.text('Recycling'));
      await tester.pumpAndSettle();

      // The welcome grid is gone, the answer is in, and the short chip row
      // took the grid's place.
      expect(find.text('What I can help with'), findsNothing);
      expect(find.text('How do I recycle properly?'), findsOneWidget);
      expect(find.textContaining('Rinse and sort recyclables'), findsOneWidget);
      expect(find.text('Collection schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a narrow phone too', (tester) async {
      await pump(tester, const Size(320, 640));
      expect(find.text('What I can help with'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
