import 'package:eco_connect/core/widgets/eco_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared page frame is used by every role's sub-screens, so a layout
/// regression here blanks dozens of pages at once. These tests pin the two
/// shapes the screens rely on: a scrolling page and a page whose body fills
/// the frame (a list with its own Expanded, a tab host, a desk).
void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: child,
  );

  testWidgets('renders the header and scrolling children', (tester) async {
    await tester.pumpWidget(
      wrap(
        EcoPageScaffold(
          eyebrow: 'BARANGAY STAFF · TEST',
          title: 'Resident validation',
          subtitle: 'Check each ID.',
          onBack: () {},
          actions: [
            EcoIconAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: () {},
            ),
          ],
          children: const [
            SizedBox(height: 80, child: Text('first')),
            SizedBox(height: 80, child: Text('second')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resident validation'), findsOneWidget);
    expect(find.text('BARANGAY STAFF · TEST'), findsOneWidget);
    expect(find.text('Check each ID.'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a filling body gets a bounded height', (tester) async {
    await tester.pumpWidget(
      wrap(
        EcoPageScaffold(
          title: 'Collection requests',
          body: Column(
            children: [
              const SizedBox(height: 40, child: Text('filters')),
              Expanded(
                child: ListView(
                  children: const [
                    SizedBox(height: 60, child: Text('row one')),
                    SizedBox(height: 60, child: Text('row two')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('filters'), findsOneWidget);
    expect(find.text('row one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bottom bar keeps its own space', (tester) async {
    await tester.pumpWidget(
      wrap(
        EcoPageScaffold(
          title: 'My routes',
          bottomBar: const SizedBox(height: 60, child: Text('nav')),
          body: const SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('nav'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
