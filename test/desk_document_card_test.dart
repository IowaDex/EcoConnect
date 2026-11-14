import 'package:eco_connect/core/theme/app_colors.dart';
import 'package:eco_connect/features/cityhall/models/desk_document.dart';
import 'package:eco_connect/features/cityhall/widgets/desk_document_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desk document card', () {
    testWidgets('shows the real driver, reference and status', (tester) async {
      await tester.pumpWidget(_wrap(_document()));

      expect(find.text('Ramon Dela Cruz'), findsOneWidget);
      expect(find.text('Truck Driver'), findsOneWidget);
      expect(find.text('TT-2026-0042'), findsOneWidget);
      expect(find.text('ABC 1234'), findsOneWidget);
      expect(find.text('Zone 3'), findsOneWidget);
      expect(find.text('Awaiting Signature'), findsOneWidget);
      expect(find.text('Trip Ticket'), findsOneWidget);
    });

    testWidgets('lays out at phone width without overflowing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _document(
            status: DeskDocumentStatus.returnedForRevision,
            title: 'A very long route name that covers several puroks in the '
                'barangay and must wrap cleanly',
            canSign: false,
          ),
          width: 300,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Returned for Revision'), findsOneWidget);
    });

    testWidgets('sign and view call the right actions', (tester) async {
      var opened = 0;
      var signed = 0;

      await tester.pumpWidget(
        _wrap(
          _document(),
          onOpen: () => opened++,
          onSign: () => signed++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View document'));
      await tester.pump();
      expect(opened, 1);
      expect(signed, 0);

      await tester.tap(find.text('Sign'));
      await tester.pump();
      expect(signed, 1);
    });

    testWidgets('memos offer acknowledge instead of sign', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _document(
            kind: DeskDocumentKind.memo,
            category: DeskCategory.barangay,
            senderName: 'Barangay Desk',
            senderRole: 'Barangay Staff',
            title: 'Schedule adjustment for wave 2',
          ),
          onSign: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Sign'), findsNothing);
      expect(find.text('Barangay'), findsWidgets);
    });

    testWidgets('a signed card only offers the document', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _document(status: DeskDocumentStatus.signed, canSign: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View document'), findsOneWidget);
      expect(find.text('Sign'), findsNothing);
    });
  });
}

Widget _wrap(
  DeskDocument document, {
  double width = 360,
  VoidCallback? onOpen,
  VoidCallback? onSign,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      backgroundColor: AppColors.creamBright,
      body: Center(
        child: SizedBox(
          width: width,
          child: DeskDocumentCard(
            document: document,
            onOpen: onOpen ?? () {},
            onSign: onSign,
          ),
        ),
      ),
    ),
  );
}

DeskDocument _document({
  DeskDocumentKind kind = DeskDocumentKind.tripTicket,
  DeskCategory category = DeskCategory.driver,
  DeskDocumentStatus status = DeskDocumentStatus.awaitingSignature,
  bool canSign = true,
  String senderName = 'Ramon Dela Cruz',
  String senderRole = 'Truck Driver',
  String title = 'Purok 1 – Purok 4',
}) {
  return DeskDocument(
    id: 't1',
    kind: kind,
    category: category,
    title: title,
    reference: 'TT-2026-0042',
    displayReference: 'TT-2026-0042',
    senderName: senderName,
    senderRole: senderRole,
    department: category.label,
    date: DateTime(2026, 11, 14, 8),
    dateCaption: 'Submitted',
    status: status,
    area: 'Zone 3',
    route: 'Purok 1 – Purok 4',
    truck: 'ABC 1234',
    driverName: senderName,
    canSign: canSign,
    openRoute: '/tickets/t1',
  );
}
