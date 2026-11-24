import 'package:eco_connect/core/widgets/desk_ui.dart';
import 'package:eco_connect/core/widgets/eco_pagination.dart';
import 'package:eco_connect/core/widgets/empty_state.dart';
import 'package:eco_connect/features/cityhall/models/desk_document.dart';
import 'package:eco_connect/features/cityhall/widgets/desk_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desk segmented', () {
    testWidgets('reports the tapped status and keeps four options readable', (
      tester,
    ) async {
      SignatureFilter? picked;

      await tester.pumpWidget(
        _sized(
          300,
          DeskSegmented<SignatureFilter>(
            segments: [
              for (final filter in SignatureFilter.values)
                DeskSegment(value: filter, label: filter.shortLabel),
            ],
            value: SignatureFilter.awaiting,
            onChanged: (filter) => picked = filter,
          ),
        ),
      );

      expect(find.text('Awaiting'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);

      await tester.tap(find.text('Rejected'));
      await tester.pump();
      expect(picked, SignatureFilter.rejected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carries a count without overflowing a phone', (tester) async {
      await tester.pumpWidget(
        _sized(
          320,
          DeskSegmented<String>(
            segments: const [
              DeskSegment(value: 'a', label: 'For signature', count: 12),
              DeskSegment(value: 'b', label: 'Received', count: 108),
            ],
            value: 'a',
            onChanged: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('desk filters', () {
    testWidgets('category bar reports the tapped office and its counts', (
      tester,
    ) async {
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

    testWidgets('shared search field reports typing and clears', (
      tester,
    ) async {
      final controller = TextEditingController();
      var query = '';

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return EcoSearchField(
                controller: controller,
                hint: 'Search document, driver name, or reference number...',
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

    testWidgets('the office chips share one row at desk width', (tester) async {
      await tester.pumpWidget(_sized(460, _categoryBar()));

      expect(_chipRows(tester), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow window falls back to two columns', (tester) async {
      await tester.pumpWidget(_sized(360, _categoryBar()));

      // Two even rows, never one cell left alone on a third row.
      expect(_chipRows(tester), hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a chip hugs its label instead of claiming a whole row', (
      tester,
    ) async {
      // The day bar stacks one chip per line when a chip expands to the width
      // it is offered, which is how the schedule filter grew eight rows tall.
      await tester.pumpWidget(
        _sized(
          360,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in ['All', 'Mon', 'Tue', 'Wed'])
                DeskFilterChip(
                  label: label,
                  selected: label == 'All',
                  onTap: () {},
                ),
            ],
          ),
        ),
      );

      expect(_chipRows(tester), hasLength(1));
      expect(
        tester.getSize(find.byType(DeskFilterChip).first).width,
        lessThan(120),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared empty state shows its action only when one is given', (
      tester,
    ) async {
      var cleared = false;

      await tester.pumpWidget(
        _wrap(
          EmptyState(
            compact: true,
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

/// The distinct row positions of the chips on screen.
Set<double> _chipRows(WidgetTester tester) {
  final chips = find.byType(DeskFilterChip);
  return {
    for (var i = 0; i < chips.evaluate().length; i++)
      tester.getTopLeft(chips.at(i)).dy,
  };
}

Widget _sized(double width, Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

Widget _categoryBar() {
  return DeskCategoryBar(
    selected: DeskCategory.barangay,
    counts: const {
      null: 4,
      DeskCategory.barangay: 2,
      DeskCategory.iswim: 1,
      DeskCategory.driver: 1,
    },
    onChanged: (_) {},
  );
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
