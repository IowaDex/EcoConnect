import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.forest,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.forest,
      secondary: AppColors.moss,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.lime,
      onSecondaryContainer: AppColors.forest,
      surface: AppColors.creamBright,
      onSurface: AppColors.forest,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.sage,
      outlineVariant: AppColors.sage,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return _base(scheme, GoogleFonts.poppinsTextTheme());
  }

  static ThemeData _base(ColorScheme scheme, TextTheme baseText) {
    final text = baseText.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final radius = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.creamBright,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        errorStyle: TextStyle(fontSize: 11, color: scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.creamBright,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.inkMuted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.sage.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
