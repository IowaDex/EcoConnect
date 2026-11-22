import 'package:eco_connect/core/design/eco_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The desk screens read their type from [EcoType] instead of spelling sizes
/// out inline. These tests pin the two things that matters: every role keeps
/// the corporate family set by the theme, and every role stays on the scale.
void main() {
  late Map<String, TextStyle> styles;

  setUp(() {
    styles = {};
  });

  testWidgets('every role inherits the corporate family from the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
        home: Builder(
          builder: (context) {
            styles = {
              'eyebrow': EcoType.eyebrow(context),
              'metricValue': EcoType.metricValue(context),
              'metricLabel': EcoType.metricLabel(context),
              'sectionTitle': EcoType.sectionTitle(context),
              'cardTitle': EcoType.cardTitle(context),
              'cardTitleLarge': EcoType.cardTitleLarge(context),
              'panelTitle': EcoType.panelTitle(context),
              'identifier': EcoType.identifier(context),
              'body': EcoType.body(context),
              'bodySmall': EcoType.bodySmall(context),
              'bodyStrong': EcoType.bodyStrong(context),
              'micro': EcoType.micro(context),
              'label': EcoType.label(context),
              'meta': EcoType.meta(context),
              'chip': EcoType.chip(context),
              'action': EcoType.action(context),
            };
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(styles, hasLength(16));
    for (final entry in styles.entries) {
      expect(
        entry.value.fontFamily,
        'Poppins',
        reason: '${entry.key} must keep the corporate face',
      );
    }
  });

  testWidgets('the scale stays on the agreed sizes and weights', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
        home: Builder(
          builder: (context) {
            styles = {
              'eyebrow': EcoType.eyebrow(context),
              'metricValue': EcoType.metricValue(context),
              'metricLabel': EcoType.metricLabel(context),
              'sectionTitle': EcoType.sectionTitle(context),
              'cardTitle': EcoType.cardTitle(context),
              'cardTitleLarge': EcoType.cardTitleLarge(context),
              'panelTitle': EcoType.panelTitle(context),
              'body': EcoType.body(context),
              'bodySmall': EcoType.bodySmall(context),
              'meta': EcoType.meta(context),
              'action': EcoType.action(context),
            };
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(styles['eyebrow']!.fontSize, 9);
    expect(styles['eyebrow']!.fontWeight, FontWeight.w800);
    expect(styles['metricValue']!.fontSize, 20);
    expect(styles['metricLabel']!.fontSize, 8);
    expect(styles['sectionTitle']!.fontSize, 14.5);
    expect(styles['cardTitle']!.fontSize, 13.5);
    expect(styles['cardTitleLarge']!.fontSize, 15);
    expect(styles['panelTitle']!.fontSize, 15);
    expect(styles['body']!.fontSize, 11.5);
    expect(styles['bodySmall']!.fontSize, 10.5);
    expect(styles['meta']!.fontSize, 9.5);
    expect(styles['action']!.fontSize, 11.5);
  });
}
