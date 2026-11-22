import 'package:eco_connect/core/design/eco_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The desk screens read their type from [EcoType] instead of spelling sizes
/// out inline. These tests pin the two things that matter: every role keeps
/// the family it is meant to use, and every role stays on the scale.
void main() {
  late Map<String, TextStyle> styles;

  /// Roles that are labels or controls. Everything else is reading copy or a
  /// heading and stays on the theme's brand face.
  const labelRoles = {
    'eyebrow',
    'metricLabel',
    'micro',
    'label',
    'chip',
    'action',
  };

  setUp(() {
    styles = {};
  });

  testWidgets('every role uses its agreed family', (tester) async {
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
      final family = entry.value.fontFamily ?? '';
      if (labelRoles.contains(entry.key)) {
        // google_fonts registers one family per weight (`PlusJakartaSans_800`),
        // so match the prefix rather than the display name.
        expect(
          family.startsWith('PlusJakartaSans'),
          isTrue,
          reason: '${entry.key} must use Plus Jakarta Sans, got $family',
        );
      } else {
        expect(
          family,
          'Poppins',
          reason: '${entry.key} must keep the brand face',
        );
      }
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
