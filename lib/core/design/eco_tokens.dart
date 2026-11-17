import 'package:flutter/animation.dart';

/// Layout and motion constants shared by the redesigned screens.
///
/// Screens built with these tokens stay visually consistent: the same rhythm
/// between sections, the same corner language, the same transition speed.
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
