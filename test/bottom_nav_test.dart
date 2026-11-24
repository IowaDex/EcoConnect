import 'package:eco_connect/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pill is placed by the Scaffold flush with the bottom of the screen, so
/// it has to lift itself above the phone's own navigation bar. Otherwise the
/// labels sit under the gesture bar and read half-faded on a real device.
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

  testWidgets('lifts the pill above the system navigation bar', (tester) async {
    await pumpNav(tester, bottomInset: 34);

    expect(tester.takeException(), isNull);
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(AppBottomNav),
            matching: find.byType(Container),
          )
          .first,
    );
    // 844 tall, 34 reserved by the system bar: the pill ends above it.
    expect(pill.bottom, lessThanOrEqualTo(844 - 34));
    expect(pill.height, 62);
  });

  testWidgets('keeps the assistant button inside the bar', (tester) async {
    await pumpNav(tester, bottomInset: 34);

    final nav = tester.getRect(find.byType(AppBottomNav));
    expect(nav.bottom, lessThanOrEqualTo(844));
    expect(tester.getRect(find.byIcon(Icons.forum_rounded)).top, greaterThan(0));
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
