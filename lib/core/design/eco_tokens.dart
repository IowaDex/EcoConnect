import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layout, motion and type constants shared by the redesigned screens.
///
/// Screens built with these tokens stay visually consistent: the same rhythm
/// between sections, the same corner language, the same transition speed, and
/// the same type.
abstract final class EcoSpace {
  const EcoSpace._();

  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class EcoRadius {
  const EcoRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double hero = 28;
  static const double pill = 999;
}

abstract final class EcoMotion {
  const EcoMotion._();
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// The corporate type scale.
///
/// Every desk screen used to spell out its own size, weight and letter spacing
/// inline, which is how a 15px title on one screen and a 16px title on the next
/// started to drift. Each role here is built from the theme's own text style, so
/// the family stays the brand face set in the app theme (Poppins) even when a
/// widget sits somewhere the default text style is not inherited — a dialog, a
/// bottom sheet, a map overlay.
///
/// Labels and controls are the exception: they take [Plus Jakarta Sans][_label],
/// a corporate grotesque that holds its shape at 8–11 pt. Headings and reading
/// copy keep Poppins, so only the chrome of a desk changes.
///
/// Sizes follow one scale: 8 / 9 / 9.5 / 10 / 11 / 11.5 / 13.5 / 14.5 / 20.
abstract final class EcoType {
  const EcoType._();

  static TextStyle _style(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? theme.colorScheme.onSurface,
    );
  }

  /// The label face: buttons, eyebrows, chips, badges and small actions.
  static TextStyle _label(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// The small uppercase line above a title, e.g. `CITY HALL · DOCUMENT DESK`.
  static TextStyle eyebrow(BuildContext context, {Color? color}) => _label(
    context,
    size: 9,
    weight: FontWeight.w800,
    letterSpacing: 1.1,
    color: color,
  );

  /// A number that leads a metric tile.
  static TextStyle metricValue(BuildContext context, {Color? color}) => _style(
    context,
    size: 20,
    weight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.4,
    color: color,
  );

  /// The caption under a metric value, always uppercased by the caller.
  static TextStyle metricLabel(BuildContext context, {Color? color}) => _label(
    context,
    size: 8,
    weight: FontWeight.w800,
    letterSpacing: 0.55,
    color: color,
  );

  /// A section heading inside a page, e.g. "Received".
  static TextStyle sectionTitle(BuildContext context, {Color? color}) => _style(
    context,
    size: 14.5,
    weight: FontWeight.w800,
    letterSpacing: -0.1,
    color: color,
  );

  /// The heading of a record card.
  static TextStyle cardTitle(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) => _style(
    context,
    size: 13.5,
    weight: weight ?? FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.1,
    color: color,
  );

  /// The heading of a feed card, one step above [cardTitle].
  static TextStyle cardTitleLarge(BuildContext context, {Color? color}) =>
      _style(
        context,
        size: 15,
        weight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
        color: color,
      );

  /// The heading of a panel that has no record to show, e.g. an empty queue.
  static TextStyle panelTitle(BuildContext context, {Color? color}) => _style(
    context,
    size: 15,
    weight: FontWeight.w800,
    height: 1.3,
    letterSpacing: -0.2,
    color: color,
  );

  /// A plate number or other short identifier set in wide tracking.
  static TextStyle identifier(BuildContext context, {Color? color}) => _style(
    context,
    size: 14,
    weight: FontWeight.w800,
    letterSpacing: 1,
    color: color,
  );

  /// Reading copy: a description, a message, a note.
  static TextStyle body(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) => _style(
    context,
    size: 11.5,
    weight: weight ?? FontWeight.w400,
    height: 1.6,
    color: color,
  );

  /// Secondary reading copy: a section subtitle, a card description.
  static TextStyle bodySmall(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) => _style(
    context,
    size: 10.5,
    weight: weight ?? FontWeight.w400,
    height: 1.45,
    color: color,
  );

  /// Reading copy that carries slightly more weight, e.g. a step in a flow.
  static TextStyle bodyStrong(BuildContext context, {Color? color}) => _style(
    context,
    size: 10,
    weight: FontWeight.w600,
    height: 1.45,
    color: color,
  );

  /// A number or unit inside a badge.
  static TextStyle micro(BuildContext context, {Color? color}) =>
      _label(context, size: 8, weight: FontWeight.w800, color: color);

  /// A small label that carries an action, e.g. "Clear filters".
  static TextStyle label(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) => _label(
    context,
    size: 10,
    weight: weight ?? FontWeight.w700,
    color: color,
  );

  /// Secondary facts under a title: time, place, author.
  static TextStyle meta(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) => _style(
    context,
    size: 9.5,
    weight: weight ?? FontWeight.w500,
    height: 1.4,
    color: color,
  );

  /// A small label inside a chip or a badge.
  static TextStyle chip(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) =>
      _label(context, size: 9, weight: weight ?? FontWeight.w700, color: color);

  /// A button label on a compact desk action.
  static TextStyle action(BuildContext context, {Color? color}) =>
      _label(context, size: 11.5, weight: FontWeight.w700, color: color);
}
