import 'package:eco_connect/core/utils/responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formGutter', () {
    test('keeps the standard gutter on phones', () {
      for (final width in [280.0, 320.0, 390.0, 430.0]) {
        expect(formGutter(width), 24, reason: 'width $width');
      }
    });

    test('caps the content measure on tablets and desktop', () {
      for (final width in [508.0, 600.0, 768.0, 1024.0, 1920.0]) {
        final gutter = formGutter(width);
        expect(width - gutter * 2, lessThanOrEqualTo(460.0),
            reason: 'width $width');
      }
    });

    test('grows the gutter smoothly past the breakpoint', () {
      expect(formGutter(708), 124);
      expect(formGutter(1024), 282);
    });
  });

  group('ScreenMetrics.heroMaxWidth', () {
    test('phones use the whole width', () {
      for (final width in [280.0, 320.0, 390.0, 430.0, 620.0]) {
        final metrics = _metrics(Size(width, 844));
        expect(metrics.heroMaxWidth, width, reason: 'width $width');
      }
    });

    test('a short wide window keeps the phone-width hero', () {
      // 1280x800 desktop: a wider hero would zoom the scene into a close-up.
      expect(_metrics(const Size(1280, 800)).heroMaxWidth, 620);
      expect(_metrics(const Size(1920, 1080)).heroMaxWidth, 648);
    });

    test('a tall tablet gets a wider hero', () {
      expect(_metrics(const Size(1024, 1366)).heroMaxWidth, 780);
    });

    test('never exceeds the window itself', () {
      final metrics = _metrics(const Size(700, 1400));
      expect(metrics.heroMaxWidth, lessThanOrEqualTo(700));
    });
  });
}

ScreenMetrics _metrics(Size size) => ScreenMetrics(
      size: size,
      windowClass: ScreenMetrics.classify(size.width),
      textScale: 1,
      viewInsets: EdgeInsets.zero,
      padding: EdgeInsets.zero,
    );
