import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eco_connect/core/widgets/brand_wordmark.dart';
import 'package:eco_connect/core/widgets/hex_leaf_logo.dart';
import 'package:eco_connect/core/widgets/primary_button.dart';

void main() {
  testWidgets('brand wordmark uses the logo as the O', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandWordmark())),
      ),
    );

    // "Ec" + hex-leaf mark standing in for the O + "Connect", set as one
    // rich span so the mark can sit on the text baseline.
    // ￼ is the object-replacement character Flutter emits for a
    // WidgetSpan, so this pins the mark exactly where the O belongs.
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.textSpan!.toPlainText(), 'Ec￼Connect');
    expect(find.byType(HexLeafLogo), findsOneWidget);
  });

  testWidgets('primary button invokes its callback', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'Log in', onPressed: () => tapped++),
        ),
      ),
    );

    await tester.tap(find.text('Log in'));
    expect(tapped, 1);
  });
}
