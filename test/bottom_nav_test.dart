import 'package:eco_connect/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Scaffold places the pill flush with the bottom of the screen, so the
/// bar has to lift itself above the phone's own navigation bar. Otherwise the
/// system menu icons (back / home / recents) draw over its labels.
void main() {
  Future<void> pumpNav(
    WidgetTester tester, {
    required double bottomInset,
    bool withAssistant = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            onAskAi: withAssistant ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect pillRect(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(AppBottomNav),
          matching: find.byType(Container),
        )
        .first,
  );

  testWidgets('lifts the resident pill above the system navigation bar', (
    tester,
  ) async {
    await pumpNav(tester, bottomInset: 34);

    expect(tester.takeException(), isNull);
    // 844 tall, 34 reserved by the system bar: the pill ends above it.
    expect(pillRect(tester).bottom, lessThanOrEqualTo(844 - 34));
    expect(pillRect(tester).height, 62);
  });

  testWidgets('lifts the plain pill the same way the Iswim bar sits', (
    tester,
  ) async {
    await pumpNav(tester, bottomInset: 34, withAssistant: false);

    expect(pillRect(tester).bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('stays put when the phone has no system bar', (tester) async {
    await pumpNav(tester, bottomInset: 0);

    // No inset, no extra gap: the pill keeps its own 12px margin.
    expect(pillRect(tester).bottom, 844 - 12);
  });

  testWidgets('does not double the inset when a screen wraps it again', (
    tester,
  ) async {
    // The Iswim desk still wraps the bar in its own SafeArea; the bar must
    // resolve to the same place it does everywhere else.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SafeArea(
            top: false,
            child: AppBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(pillRect(tester).bottom, 844 - 34 - 12);
  });

  testWidgets('fits a short phone without the assistant button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: 3, onTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Profile'), findsOneWidget);
  });
}
