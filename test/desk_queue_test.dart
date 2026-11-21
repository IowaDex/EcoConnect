import 'package:eco_connect/core/widgets/desk_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every City Hall queue is built from [DeskQueueView], so a layout regression
/// here blanks the request desk, delays, Wave 2 and the incident desk at once.
/// These tests pin the two shapes the screens rely on: an empty queue that
/// still reads as a desk, and a filled queue that scrolls without overflowing.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: SafeArea(child: child)),
  );

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget queue({required int itemCount}) => DeskQueueView(
    metrics: const [
      DeskMetric(icon: Icons.timer_outlined, label: 'At DSQC', value: '2'),
      DeskMetric(
        icon: Icons.local_police_outlined,
        label: 'With district',
        value: '1',
      ),
      DeskMetric(icon: Icons.campaign_outlined, label: 'Announced', value: '0'),
    ],
    search: const SizedBox(height: 44),
    filters: const SizedBox(height: 40),
    resultLine: DeskResultLine(label: '$itemCount reports'),
    empty: DeskEmptyQueue(
      icon: Icons.timer_outlined,
      title: 'No delay reports yet',
      message:
          'When a collection runs late, Iswim files it here and the DSQC '
          'decides who needs to know.',
      steps: const [
        'Iswim files the late round',
        'DSQC pushes it to the district officer',
        'The barangay gets its copy',
      ],
      actionLabel: 'Clear filters',
      actionIcon: Icons.filter_alt_off_outlined,
      onAction: () {},
    ),
    itemCount: itemCount,
    itemBuilder: (_, index) => Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE3D2)),
      ),
      child: Text('record $index'),
    ),
  );

  testWidgets('an empty queue keeps its guidance on a phone screen', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(host(queue(itemCount: 0)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No delay reports yet'), findsOneWidget);
    expect(find.text('HOW IT FLOWS'), findsOneWidget);
    expect(find.text('DSQC pushes it to the district officer'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('a filled queue scrolls and still reports the total', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(host(queue(itemCount: 12)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('12 reports'), findsOneWidget);
    expect(find.text('record 0'), findsOneWidget);
    expect(find.text('No delay reports yet'), findsNothing);

    await tester.drag(find.text('record 0'), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('record 0'), findsNothing);
  });

  testWidgets('an empty queue survives a short landscape window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(queue(itemCount: 0)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No delay reports yet'), findsOneWidget);
  });
}
