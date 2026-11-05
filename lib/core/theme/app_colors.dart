import 'package:flutter/material.dart';

/// Palette sampled directly from the EcoConnect design reference video.
abstract final class AppColors {
  /// Deep forest green — primary brand colour, buttons, headings.
  static const forest = Color(0xFF064121);

  /// Slightly darker forest used for gradients and pressed states.
  static const forestDeep = Color(0xFF03301A);

  /// Muted moss green — secondary accents, icons.
  static const moss = Color(0xFF5C8149);

  /// Bright lime accent used on badges and highlights.
  static const lime = Color(0xFF97C65D);

  /// Pale mint — splash / hero backgrounds.
  static const mint = Color(0xFFE2F2D3);

  /// Lighter mint for gradient ends.
  static const mintSoft = Color(0xFFF1F8E9);

  /// Warm cream — auth sheets and card surfaces.
  static const cream = Color(0xFFF7F7D6);

  /// Bright cream — page background.
  static const creamBright = Color(0xFFFBFBEA);

  /// Sage outline / divider colour.
  static const sage = Color(0xFFC6D5B3);

  /// Muted body text on cream.
  static const inkMuted = Color(0xFF6F7F69);

  /// Error red.
  static const danger = Color(0xFFB3261E);

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mint, mintSoft],
  );

  static const forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [forest, forestDeep],
  );
}
