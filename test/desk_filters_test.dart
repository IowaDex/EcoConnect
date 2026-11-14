import 'package:eco_connect/features/cityhall/models/desk_document.dart';
import 'package:eco_connect/features/cityhall/widgets/desk_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desk filters', () {
    testWidgets('category bar reports the tapped office and its counts',
        (tester) async {
      DeskCategory? selected;
      var cleared = false;

      await tester.pumpWidget(
        _wrap(
          DeskCategoryBar(
            selected: DeskCategory.driver,
            counts: const {
              null: 12,
              DeskCategory.barangay: 3,
              DeskCategory.iswim: 2,
              DeskCategory.driver: 7,
            },
            onChanged: (category) {
              if (category == null) {
                cleared = true;
              } else {
                selected = category;
              }
            },
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Barangay'), findsOneWidget);
      expect(find.text('ISWIM'), findsOneWidget);
      expect(find.text('Truck Drivers'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.text('ISWIM'));
      await tester.pump();
      expect(selected, DeskCategory.iswim);

      await tester.tap(find.text('All'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('signature bar reports the tapped status', (tester) async {
      SignatureFilter? selected;

      await tester.pumpWidget(
        _wrap(
          DeskSignatureBar(
            selected: SignatureFilter.awaiting,
            counts: const {
              SignatureFilter.awaiting: 4,
              SignatureFilter.signed: 9,
              SignatureFilter.rejected: 1,
              SignatureFilter.returned: 2,
            },
            onChanged: (filter) => selected = filter,
          ),
        ),
      );

      expect(find.text('Awaiting Signature'), findsOneWidget);
      expect(find.text('Returned for Revision'), findsOneWidget);

      await tester.tap(find.text('Signed'));
      await tester.pump();
      expect(selected, SignatureFilter.signed);
    });

    testWidgets('search field reports typing and clears', (tester) async {
      final controller = TextEditingController();
      var query = '';

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return DeskSearchField(
                controller: controller,
                hintText: 'Search document, driver name, or reference number...',
                onChanged: (value) => setState(() => query = value),
              );
            },
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Ramon');
      await tester.pump();
      expect(query, 'Ramon');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(query, isEmpty);
      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      controller.dispose();
    });

    testWidgets('empty state shows its action only when one is given',
        (tester) async {
      var cleared = false;

      await tester.pumpWidget(
        _wrap(
          DeskEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No documents match your filters',
            message: 'Try another category.',
            actionLabel: 'Clear filters',
            onAction: () => cleared = true,
          ),
        ),
      );

      expect(find.text('No documents match your filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}
