import 'package:eco_connect/core/utils/image_payload.dart';
import 'package:eco_connect/features/auth/models/account_type.dart';
import 'package:eco_connect/features/staff/widgets/resident_review_sheet.dart';
import 'package:eco_connect/features/verification/models/verification_request.dart';
import 'package:eco_connect/features/verification/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1x1 PNG, enough to prove the ID image is laid out and drawn.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

class _FakeVerification extends Fake implements VerificationService {
  _FakeVerification(this.document);

  final UploadPayload? document;

  @override
  Future<VerificationRequest?> fetchForUser(String userId) async =>
      VerificationRequest(
        id: userId,
        userId: userId,
        name: 'Ken',
        email: 'ken@example.com',
        accountType: AccountType.resident,
        document: document,
      );
}

Future<void> _pump(WidgetTester tester, _FakeVerification fake,
    {Map<String, dynamic>? account}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ResidentReviewSheet(
        account: account ??
            {
              'uid': 'ken',
              'name': 'Ken',
              'email': 'ken@example.com',
              'phone': '+639171234567',
              'barangay': 'Batasan Hills',
              'accountStatus': 'pending',
              'emailVerified': true,
            },
        verification: fake,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the resident\'s ID photo is shown with their details',
      (tester) async {
    await _pump(
      tester,
      _FakeVerification(const UploadPayload(
        dataUrl: _png,
        fileName: 'id.png',
        mimeType: 'image/png',
        bytes: 68,
      )),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('ken@example.com'), findsOneWidget);
    expect(find.text('Batasan Hills'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('a missing ID says so instead of showing nothing',
      (tester) async {
    await _pump(tester, _FakeVerification(null));

    expect(find.text('This resident did not upload an ID.'), findsOneWidget);
  });

  testWidgets('approve waits for a new sign-up to confirm their email',
      (tester) async {
    await _pump(
      tester,
      _FakeVerification(null),
      account: {
        'uid': 'kim',
        'name': 'Kim',
        'accountStatus': 'pending',
        'emailVerified': false,
      },
    );

    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Approve'),
    );
    expect(approve.onPressed, isNull);
    expect(
      find.text('You can approve once the resident confirms their email.'),
      findsOneWidget,
    );
  });
}
