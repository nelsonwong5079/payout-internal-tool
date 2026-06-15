import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Restrained zinc tokens — flat surfaces, one accent, clear hierarchy.
abstract final class AppColors {
  static const void_ = Color(0xFF09090B);
  static const canvas = Color(0xFF09090B);
  static const canvasDark = canvas;
  static const surface = Color(0xFF18181B);
  static const surfaceDark = surface;
  static const surfaceElevated = Color(0xFF1C1C1F);
  static const surfaceMuted = Color(0xFF27272A);
  static const glass = Color(0x08FFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);

  static const accent = Color(0xFF6366F1);
  static const accentHover = Color(0xFF818CF8);
  static const cyan = accent;
  static const cyanBright = accentHover;
  static const violet = Color(0xFF8B5CF6);
  static const violetDeep = Color(0xFF6D28D9);

  static const primary = accent;
  static const primaryDark = Color(0xFF4F46E5);

  static const borderDark = Color(0xFF27272A);
  static const borderSubtle = Color(0xFF3F3F46);

  static const textPrimary = Color(0xFFFAFAFA);
  static const textOnDark = textPrimary;
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMutedOnDark = Color(0xFF71717A);

  static const success = Color(0xFF22C55E);
  static const successDark = Color(0xFF16A34A);
  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  static const canvasLight = canvas;
  static const surfaceLight = surfaceElevated;
}

abstract final class AppRadii {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
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

abstract final class AppTypography {
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get title => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 13,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textMutedOnDark,
      );

  static TextStyle mono({double size = 12, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: 1.45,
        color: color ?? AppColors.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle data({double size = 20, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

abstract final class AppTheme {
  static TextTheme _textTheme() {
    final base = ThemeData.dark().textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      headlineLarge: AppTypography.display,
      headlineMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      titleLarge: AppTypography.title,
      titleMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: AppTypography.body,
      labelSmall: AppTypography.label,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentHover,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      useMaterial3: true,
      brightness: Brightness.dark,
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
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          side: const BorderSide(color: AppColors.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hoverColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.inter(color: AppColors.textMutedOnDark),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.textPrimary),
      ),
    );
  }

  static ThemeData light() => dark();

  static BoxDecoration panelDecoration({
    double radius = AppRadii.lg,
    Color? color,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color ?? AppColors.surfaceElevated,
      border: Border.all(color: AppColors.glassBorder),
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
    return panelDecoration(radius: radius);
  }

  static BoxDecoration lightCardDecoration({double radius = AppRadii.lg}) {
    return panelDecoration(radius: radius);
  }
}
