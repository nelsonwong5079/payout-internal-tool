import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Research-workbench tokens — light canvas, fluorescent yellow accent, black ink.
/// White / yellow / black only for primary UI; status colors stay functional.
abstract final class AppColors {
  /// Paper / lab bench base.
  static const void_ = Color(0xFFF4F3EE);
  static const canvas = Color(0xFFF4F3EE);
  static const canvasDark = Color(0xFFE8E6DF);
  static const surface = Color(0xFFFAFAF7);
  static const surfaceDark = surface;
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFEDE6);
  static const glass = Color(0x14FFE500);
  static const glassBorder = Color(0xE0121212);

  /// Fluorescent yellow — sole primary accent.
  static const accent = Color(0xFFFFE500);
  static const accentHover = Color(0xFFFFF06A);
  static const accentDeep = Color(0xFFE6CF00);
  static const cyan = accent;
  static const cyanBright = accentHover;
  static const violet = Color(0xFF1A1A1A);
  static const violetDeep = Color(0xFF000000);

  static const primary = accent;
  static const primaryDark = accentDeep;

  /// Ink — strokes, type, solid controls.
  static const ink = Color(0xFF121212);
  static const inkSoft = Color(0xFF2A2A2A);
  static const borderDark = Color(0xFF121212);
  static const borderSubtle = Color(0x66121212);
  static const borderHairline = Color(0x33121212);

  static const textPrimary = Color(0xFF121212);
  static const textOnDark = Color(0xFFFAFAF7);
  static const textOnAccent = Color(0xFF121212);
  static const textSecondary = Color(0xFF4A4A4A);
  static const textMutedOnDark = Color(0xFF6B6B6B);

  static const success = Color(0xFF1B7A3D);
  static const successDark = Color(0xFF145C2E);
  static const error = Color(0xFFC62828);
  static const errorDark = Color(0xFF8E1B1B);
  static const warning = Color(0xFFB45309);

  static const canvasLight = canvas;
  static const surfaceLight = surfaceElevated;

  /// Text on solid black controls.
  static const onInk = Color(0xFFFFE500);
}

/// Hard edges by default — tech terminal, not soft UI.
abstract final class AppRadii {
  static const sm = 0.0;
  static const md = 2.0;
  static const lg = 2.0;
  static const xl = 4.0;
  static const xxl = 4.0;
}

/// 4px base spacing scale.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const page = 24.0;
  static const section = 20.0;
  static const card = 20.0;
}

abstract final class AppMotion {
  static const Duration snap = Duration(milliseconds: 120);
  static const Duration panel = Duration(milliseconds: 180);
  static const Curve curve = Curves.easeOutCubic;
}

abstract final class AppTypography {
  /// Heavy display — IBM Plex Sans (much lighter than Noto Sans SC on web).
  static TextStyle get display => GoogleFonts.ibmPlexSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get title => GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => GoogleFonts.ibmPlexMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 1.2,
        color: AppColors.textMutedOnDark,
      );

  static TextStyle mono({double size = 12, Color? color, FontWeight? weight}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.4,
        color: color ?? AppColors.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle data({double size = 20, Color? color}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

abstract final class AppTheme {
  static TextTheme _textTheme() {
    final base = ThemeData.light().textTheme;
    return GoogleFonts.ibmPlexSansTextTheme(base).copyWith(
      headlineLarge: AppTypography.display,
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      titleLarge: AppTypography.title,
      titleMedium: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: AppTypography.body,
      labelSmall: AppTypography.label,
    );
  }

  /// Primary app theme (research workbench). Name kept for call-site stability.
  static ThemeData dark() => light();

  static ThemeData light() {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.ink,
        onSecondary: AppColors.onInk,
        surface: AppColors.surfaceElevated,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnDark,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: _textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: AppTypography.title,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.ink, width: 1.25),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderHairline,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textMutedOnDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: const BorderSide(color: AppColors.ink, width: 1.25),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textMutedOnDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: const BorderSide(color: AppColors.ink, width: 1.25),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          side: const BorderSide(color: AppColors.ink, width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surfaceElevated;
        }),
        checkColor: WidgetStateProperty.all(AppColors.ink),
        side: const BorderSide(color: AppColors.ink, width: 1.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ink;
          return AppColors.surfaceMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.borderSubtle;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        hoverColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.25),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.25),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.25),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.ibmPlexMono(
          color: AppColors.textMutedOnDark,
          fontSize: 12,
        ),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.ibmPlexMono(
          color: AppColors.onInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.ink, width: 1.25),
        ),
        textStyle: GoogleFonts.ibmPlexSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          border: Border.all(color: AppColors.accent, width: 1),
        ),
        textStyle: GoogleFonts.ibmPlexMono(
          color: AppColors.onInk,
          fontSize: 11,
        ),
      ),
    );
  }

  static BoxDecoration panelDecoration({
    double radius = AppRadii.lg,
    Color? color,
    bool selected = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: selected
          ? AppColors.accent.withValues(alpha: 0.35)
          : (color ?? AppColors.surfaceElevated),
      border: Border.all(
        color: AppColors.ink,
        width: selected ? 1.75 : 1.25,
      ),
    );
  }

  static BoxDecoration glassDecoration({
    double radius = AppRadii.lg,
    Color? tint,
  }) {
    return panelDecoration(
      radius: radius,
      color: tint ?? AppColors.surfaceElevated,
    );
  }

  static BoxDecoration darkPanelDecoration({double radius = AppRadii.lg}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: AppColors.ink,
      border: Border.all(color: AppColors.accent, width: 1.25),
    );
  }

  static BoxDecoration lightCardDecoration({double radius = AppRadii.lg}) {
    return panelDecoration(radius: radius);
  }
}
