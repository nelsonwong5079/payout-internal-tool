import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern zinc-based design tokens.
abstract final class AppColors {
  static const void_ = Color(0xFF09090B);
  static const canvas = Color(0xFF09090B);
  static const canvasDark = canvas;
  static const surface = Color(0xFF18181B);
  static const surfaceDark = surface;
  static const surfaceElevated = Color(0xFF1F1F23);
  static const surfaceMuted = Color(0xFF27272A);
  static const glass = Color(0x0AFFFFFF);
  static const glassBorder = Color(0x1FFFFFFF);

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
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const xxl = 24.0;
}

abstract final class AppSpacing {
  static const page = 28.0;
  static const section = 20.0;
  static const card = 24.0;
}

abstract final class AppTheme {
  static TextTheme _textTheme() {
    final base = ThemeData.dark().textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.textMutedOnDark,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.dark(
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
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.void_,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

  static LinearGradient get brandGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.accent, AppColors.accentHover],
      );

  static LinearGradient get darkPanelGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.surfaceElevated, AppColors.surface],
      );

  static BoxDecoration glassDecoration({
    double radius = AppRadii.lg,
    Color? tint,
    bool glow = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: AppColors.surfaceElevated.withValues(alpha: 0.72),
      border: Border.all(
        color: glow
            ? AppColors.accent.withValues(alpha: 0.25)
            : AppColors.glassBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration darkPanelDecoration({double radius = AppRadii.xl}) {
    return glassDecoration(radius: radius);
  }

  static BoxDecoration lightCardDecoration({double radius = AppRadii.lg}) {
    return glassDecoration(radius: radius);
  }
}
