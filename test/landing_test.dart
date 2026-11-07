import 'package:eco_connect/features/landing/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the hero on a phone-sized window and waits out the minimum boot
/// window plus the entry-slot crossfade.
Future<void> _pumpHero(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pumps the hero on an arbitrary window, optionally with a system inset and
/// an accessibility text scale.
Future<void> _pumpHeroAt(
  WidgetTester tester,
  Size size, {
  EdgeInsets safeArea = EdgeInsets.zero,
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(
    top: safeArea.top,
    bottom: safeArea.bottom,
    left: safeArea.left,
    right: safeArea.right,
  );
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // Tear the previous screen down first so every size starts a fresh boot
  // rather than reusing the state left over from the size before it.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pumps the hero and stops while it is still booting.
Future<void> _pumpBootingAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The widget the artwork is drawn into.
final Finder _artwork = find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName.endsWith('splash_city.png'),
);

void main() {
  testWidgets('landing page shows the brand promise and entry points',
      (tester) async {
    await _pumpHero(tester);

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(
      find.text(
        'Connecting Communities for a Cleaner and Greener Tomorrow.',
      ),
      findsOneWidget,
    );
    expect(find.text('Smarter waste collection\nfor every barangay'),
        findsOneWidget);

    // Dispose the animation controllers so no ticker survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the truck holds the entry slot before the buttons appear',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    // Still inside the minimum boot window: truck on screen, no buttons yet.
    expect(find.text('Starting up'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('adapts to phone, desktop and landscape without overflowing',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Phone portrait: everything stacks in one column.
    tester.view.physicalSize = const Size(390, 844);
    await _pumpHero(tester);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Connecting Communities for a Cleaner and Greener '
        'Tomorrow.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Desktop: the hero stays centred instead of stretching edge to edge.
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Landscape phone: the panel tightens up so the scene still shows.
    tester.view.physicalSize = const Size(740, 380);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('I already have an account'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // A narrow phone with a large accessibility font must not overflow either.
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lays out on every device class without overflowing',
      (tester) async {
    for (final device in _devices.entries) {
      final size = device.value;
      await _pumpHeroAt(tester, size);
      final reason = '${device.key} ${size.width.toInt()}x${size.height.toInt()}';

      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text('Get Started'), findsOneWidget, reason: reason);
      expect(
        find.text('I already have an account'),
        findsOneWidget,
        reason: reason,
      );
      expect(
        find.text('Smarter waste collection\nfor every barangay'),
        findsOneWidget,
        reason: reason,
      );
      expect(_artwork, findsOneWidget, reason: reason);

      // Every entry point has to sit fully inside the window.
      for (final label in ['Get Started', 'I already have an account']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$reason · $label');
        expect(
          rect.bottom,
          lessThanOrEqualTo(size.height),
          reason: '$reason · $label',
        );
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$reason · $label');
        expect(
          rect.right,
          lessThanOrEqualTo(size.width),
          reason: '$reason · $label',
        );
      }

      // The wordmark must never be swallowed by the panel.
      final brand = tester.getRect(find.text('EC'));
      final headline = tester.getRect(
        find.text('Smarter waste collection\nfor every barangay'),
      );
      expect(brand.top, greaterThanOrEqualTo(0), reason: reason);
      expect(
        brand.bottom,
        lessThanOrEqualTo(headline.top),
        reason: '$reason · brand overlaps the panel',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps the wordmark clear of the notch and the home indicator',
      (tester) async {
    const size = Size(390, 844);
    // iPhone 14 style chrome: 47 top, 34 bottom.
    await _pumpHeroAt(
      tester,
      size,
      safeArea: const EdgeInsets.only(top: 47, bottom: 34),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('EC')).top,
      greaterThanOrEqualTo(47),
      reason: 'wordmark is under the notch',
    );
    // The buttons must clear the home indicator.
    final button = tester.getRect(find.text('I already have an account'));
    expect(
      button.bottom,
      lessThanOrEqualTo(size.height - 34),
      reason: 'entry points are under the home indicator',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('survives a large accessibility font on phone and tablet',
      (tester) async {
    for (final size in const [Size(320, 568), Size(768, 1024)]) {
      await _pumpHeroAt(tester, size, textScale: 1.6);
      final reason = '${size.width.toInt()}x${size.height.toInt()} @1.6x';

      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text('Get Started'), findsOneWidget, reason: reason);
      expect(
        tester.getRect(find.text('Get Started')).bottom,
        lessThanOrEqualTo(size.height),
        reason: reason,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the splash lays out on every device class too', (tester) async {
    for (final device in _devices.entries) {
      final size = device.value;
      await _pumpBootingAt(tester, size);
      final reason =
          '${device.key} ${size.width.toInt()}x${size.height.toInt()}';

      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text('Starting up'), findsOneWidget, reason: reason);
      expect(find.text('Get Started'), findsNothing, reason: reason);
      expect(_artwork, findsOneWidget, reason: reason);

      // The status line is a caption on the grass, so it has to stay inside.
      final status = tester.getRect(find.text('Starting up'));
      expect(status.bottom, lessThanOrEqualTo(size.height), reason: reason);
      // ...and it must not run into the wordmark above it.
      expect(
        status.top,
        greaterThan(tester.getRect(find.text('EC')).bottom),
        reason: '$reason · status line collides with the brand',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Real logical viewports, smallest to largest, spanning both platforms and
/// every form factor the app can be installed on.
const Map<String, Size> _devices = <String, Size>{
  'Galaxy Fold (outer)': Size(280, 653),
  'iPhone SE (1st gen)': Size(320, 568),
  'iPhone SE (2nd gen)': Size(375, 667),
  'iPhone 14': Size(390, 844),
  'Pixel 7': Size(412, 915),
  'iPhone 14 Pro Max': Size(430, 932),
  'iPad mini (portrait)': Size(744, 1133),
  'Android tablet': Size(800, 1280),
  'iPad Air (portrait)': Size(820, 1180),
  'iPad Pro 12.9 (portrait)': Size(1024, 1366),
  'iPad Air (landscape)': Size(1180, 820),
  'Phone (landscape)': Size(844, 390),
  'Laptop': Size(1280, 800),
  'Desktop': Size(1920, 1080),
};
