import 'package:flutter/widgets.dart';

/// Horizontal gutter that keeps a form at a comfortable reading measure.
///
/// Phones get a fixed [gutter]; wider windows grow the gutter so the fields
/// never stretch past [maxContentWidth]. Text inputs that span a whole tablet
/// are unreadable and hard to aim at, so this is the one rule every entry form
/// shares.
double formGutter(
  double windowWidth, {
  double gutter = 24,
  double maxContentWidth = 460,
}) {
  if (windowWidth <= maxContentWidth + gutter * 2) return gutter;
  return (windowWidth - maxContentWidth) / 2;
}

/// Window classes used by the entry flow.
///
/// These follow the Material 3 size classes, narrowed to the three the app
/// actually differentiates. Every screen that adapts reads from
/// [ScreenMetrics] instead of hard-coding `MediaQuery.sizeOf` checks.
enum WindowClass {
  /// Phones in portrait — one stacked column.
  compact,

  /// Large phones, small tablets, phones in landscape — two columns.
  medium,

  /// Tablets in landscape and desktop — two columns with a wider gutter.
  expanded,
}

/// A snapshot of the window, plus the helpers needed to size a layout from it.
///
/// Sizes are declared as a pair — "this much on a phone, that much on a
/// desktop" — and resolved with [scale]. That keeps a single widget tree
/// adaptive instead of forking the build method on every breakpoint.
@immutable
class ScreenMetrics {
  const ScreenMetrics({
    required this.size,
    required this.windowClass,
    required this.textScale,
    required this.viewInsets,
    required this.padding,
  });

  /// Full window size in logical pixels.
  final Size size;

  final WindowClass windowClass;

  /// The user's accessibility text scale, already clamped so a 2x setting
  /// cannot overflow the fixed-height hero.
  final double textScale;

  /// Keyboard inset — the entry screens shift their buttons above it.
  final EdgeInsets viewInsets;

  /// System chrome — notch, status bar, home indicator, gesture bar. Anything
  /// that draws near an edge has to stay out of this.
  final EdgeInsets padding;

  /// Below this width the layout stacks.
  static const double compactMax = 600;

  /// At or above this width the layout gets generous gutters.
  static const double mediumMax = 840;

  /// The narrowest and widest windows [scale] interpolates between.
  static const double _minWidth = 320;
  static const double _maxWidth = 900;

  /// Widest the hero column gets on a phone. Past this the page stops looking
  /// like a phone and starts looking like a stretched poster.
  static const double _heroPhoneWidth = 620;

  /// Hard ceiling for the hero, however wide the window is.
  static const double _heroMaxWidth = 780;

  /// Fallback used when a widget is built outside a [MediaQuery] (tests,
  /// golden previews). Matches a common phone viewport.
  static const Size _fallbackSize = Size(390, 844);

  factory ScreenMetrics.of(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final size = media?.size ?? _fallbackSize;
    final rawScale = media == null ? 1.0 : media.textScaler.scale(1);
    return ScreenMetrics(
      size: size,
      windowClass: classify(size.width),
      textScale: rawScale.clamp(1.0, 1.25),
      viewInsets: media?.viewInsets ?? EdgeInsets.zero,
      padding: media?.padding ?? EdgeInsets.zero,
    );
  }

  static WindowClass classify(double width) {
    if (width < compactMax) return WindowClass.compact;
    if (width < mediumMax) return WindowClass.medium;
    return WindowClass.expanded;
  }

  /// The width the hero column is allowed to take on this window.
  ///
  /// Phones use the full width. Past that the hero stays a centred portrait
  /// column — but how wide it may get is driven by the window *height*, not
  /// its width: a wider hero means a proportionally taller illustration, and
  /// only the bottom slice of that illustration is ever on screen. Keying the
  /// growth to height is what stops a short, wide desktop window from zooming
  /// the scene into a close-up of the truck.
  double get heroMaxWidth {
    if (size.width <= _heroPhoneWidth) return size.width;
    final byHeight =
        (size.height * 0.60).clamp(_heroPhoneWidth, _heroMaxWidth);
    return size.width < byHeight ? size.width : byHeight;
  }

  bool get isCompact => windowClass == WindowClass.compact;
  bool get isMedium => windowClass == WindowClass.medium;
  bool get isExpanded => windowClass == WindowClass.expanded;

  /// True when the window is wider than it is tall.
  bool get isLandscape => size.width > size.height;

  /// Short windows (landscape phones, small laptops) cannot afford the full
  /// copy stack, so they drop the paragraph and tighten the vertical rhythm.
  bool get isShort => size.height < 700;

  /// True when the hero should stack its bands instead of splitting into
  /// columns.
  bool get isStacked => isCompact && !isShort;

  /// Resolves a size that differs between a phone and a desktop.
  ///
  /// The value moves linearly from [atCompact] at 320 dp to [atExpanded] at
  /// 900 dp, then stops. Capping the far end keeps a maximised desktop window
  /// from blowing the type up to poster size.
  double scale(double atCompact, double atExpanded) {
    final t =
        ((size.width - _minWidth) / (_maxWidth - _minWidth)).clamp(0.0, 1.0);
    return atCompact + (atExpanded - atCompact) * t;
  }

  /// Width to give the text column in the split layout.
  double get sideColumnWidth {
    if (isExpanded) return (size.width * 0.46).clamp(380.0, 620.0);
    return (size.width * 0.5).clamp(300.0, 460.0);
  }
}
