import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.lightGreen,
          onPrimaryContainer: AppColors.darkGreen,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.lightGreen,
          onSecondaryContainer: AppColors.darkGreen,
          surface: AppColors.background,
          onSurface: AppColors.textDark,
          onSurfaceVariant: AppColors.inkMuted,
          outline: AppColors.sage,
          outlineVariant: AppColors.sage,
          error: AppColors.error,
          onError: Colors.white,
          tertiary: AppColors.warning,
          onTertiary: AppColors.textDark,
        );

    // Body copy, headings and the brand stay on Poppins. Only buttons and
    // labels switch to Plus Jakarta Sans — see [_labelFont] below.
    return _base(scheme, GoogleFonts.poppinsTextTheme());
  }

  static ThemeData _base(ColorScheme scheme, TextTheme baseText) {
    final text = baseText.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final radius = BorderRadius.circular(14);

    /// Hover feedback for the filled buttons: a light wash plus a soft green
    /// lift, so a pointer resting on the primary action is obvious without
    /// changing the button's colour.
    final filledButton = FilledButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: _labelFont(
        fontSize: 14.5,
        letterSpacing: 0.2,
      ),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.24);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.15);
        }
        return null;
      }),
      elevation: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 3 : 0,
      ),
      shadowColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.45),
      ),
    );

    final outlinedButton = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 1.2),
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: _labelFont(fontSize: 14),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.08);
        }
        return null;
      }),
    );

    final textButton = TextButton.styleFrom(
      foregroundColor: scheme.primary,
      textStyle: _labelFont(fontSize: 12.5),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: 0.08);
        }
        return null;
      }),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.comfortable,
      // Every InkWell in the app gets the same mint wash under the pointer,
      // so a tappable label or row never looks inert on hover.
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      focusColor: scheme.primary.withValues(alpha: 0.08),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: EcoPageTransitionsBuilder(),
          TargetPlatform.iOS: EcoPageTransitionsBuilder(),
          TargetPlatform.windows: EcoPageTransitionsBuilder(),
          TargetPlatform.macOS: EcoPageTransitionsBuilder(),
          TargetPlatform.linux: EcoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: EcoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.darkGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 58,
        titleSpacing: 4,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.darkGreen,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        errorStyle: TextStyle(fontSize: 11, color: scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButton),
      textButtonTheme: TextButtonThemeData(style: textButton),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGreen,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
        labelStyle: _labelFont(
          fontSize: 11,
          color: AppColors.darkGreen,
        ),
        secondaryLabelStyle: _labelFont(
          fontSize: 11,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGreen,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.09);
            }
            return null;
          }),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.sage.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lightGreen,
      ),
    );
  }
}

/// The face used for button text and small labels.
///
/// Plus Jakarta Sans is a contemporary corporate grotesque: even stroke widths
/// and a tall x-height keep 9–14 pt labels crisp, where Poppins' geometric
/// letterforms read as decorative. Body copy, headings and the wordmark keep
/// Poppins, so the app's voice does not change — only its controls do.
TextStyle _labelFont({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w600,
  double? letterSpacing,
  Color? color,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
  );
}

/// Route transition shared by every platform: the new page fades in while
/// rising a few pixels, so navigation feels continuous instead of a hard cut.
///
/// The same builder is used on mobile and web so the app behaves the same in
/// a browser and on a phone.
class EcoPageTransitionsBuilder extends PageTransitionsBuilder {
  const EcoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
