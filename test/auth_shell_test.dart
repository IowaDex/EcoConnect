import 'package:eco_connect/features/auth/widgets/auth_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The entry shell is shared by login, sign-up and password recovery, so it has
/// to hold its shape at every window class: no clipped form, no overflow, and
/// the hero copy only when there is room to read it.
void main() {
  setUpAll(() {
    // Widget tests have no network; use the fallback face instead of letting
    // the font package try to fetch one.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget shell() => AuthPageShell(
    onBack: () {},
    headline: 'Locked out?\nWe\'ll get you back in.',
    heroSubtitle: 'One secure link, sent to the email on your account.',
    heroSteps: const [
      AuthHeroStep('Enter the email you signed up with'),
      AuthHeroStep('Open the link we send you'),
      AuthHeroStep('Choose a new password'),
    ],
    form: const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Text('FORM BODY'),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(MaterialApp(home: shell()));
    await tester.pumpAndSettle();
  }

  testWidgets('stacks the scene over the form on a phone', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('FORM BODY'), findsOneWidget);
    // The phone hero keeps the headline but has no room for the steps.
    expect(find.text('Locked out?\nWe\'ll get you back in.'), findsOneWidget);
    expect(find.text('Enter the email you signed up with'), findsNothing);
  });

  testWidgets('keeps the form on screen on a short phone', (tester) async {
    await pumpAt(tester, const Size(320, 600));

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.text('FORM BODY'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('gives the form the room when the keyboard is open', (
    tester,
  ) async {
    await pumpAt(tester, const Size(390, 844), keyboard: 320);

    expect(tester.takeException(), isNull);
    expect(find.text('FORM BODY'), findsOneWidget);
    // The hero collapses to the brand row, so its headline steps aside.
    expect(find.text('Locked out?\nWe\'ll get you back in.'), findsNothing);
  });

  testWidgets('splits the scene and the form on a wide window', (tester) async {
    await pumpAt(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('FORM BODY'), findsOneWidget);
    // A tall desktop hero explains the three steps.
    expect(find.text('Enter the email you signed up with'), findsOneWidget);
    expect(find.text('Choose a new password'), findsOneWidget);

    // The form sits in its own pane, clear of the artwork.
    final form = tester.getRect(find.text('FORM BODY'));
    expect(form.left, greaterThan(1280 * 0.5));
  });

  testWidgets('drops the hero copy that no longer fits', (tester) async {
    // Exactly at the split, and shorter than the subtitle threshold.
    await pumpAt(tester, const Size(900, 560));

    expect(tester.takeException(), isNull);
    expect(find.text('FORM BODY'), findsOneWidget);
    expect(find.text('Locked out?\nWe\'ll get you back in.'), findsOneWidget);
    expect(
      find.text('One secure link, sent to the email on your account.'),
      findsNothing,
    );
    expect(find.text('Choose a new password'), findsNothing);
  });
}
