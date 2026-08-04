import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme tokens for the NZ trip adventure UI (this section only).
abstract final class NzColors {
  static const skyTop = Color(0xFFB8E4F8);
  static const skyMid = Color(0xFF7EC8E8);
  static const lake = Color(0xFF2BB3C0); // Tekapo turquoise
  static const fern = Color(0xFF2D6A4F);
  static const fernLight = Color(0xFF52B788);
  static const hill = Color(0xFF95D5B2);
  static const snow = Color(0xFFF8FBFF);
  static const peak = Color(0xFFE8EEF5);
  static const gold = Color(0xFFF4A261); // golden-hour
  static const goldDeep = Color(0xFFE76F51);
  static const night = Color(0xFF1B263B);
  static const ink = Color(0xFF1A2E28);
  static const inkSoft = Color(0xFF3D5A50);
  static const card = Color(0xFFFFFFF8);
  static const cardBorder = Color(0xFFD8EDE4);
  static const muted = Color(0xFF6B8F80);
  static const me = Color(0xFF1B7A6E); // forest teal
  static const cat = Color(0xFFE07A5F); // warm coral
  static const priority = Color(0xFFF2CC8F);
  static const success = Color(0xFF40916C);
  static const bought = Color(0xFFE9C46A);
}

abstract final class NzType {
  static TextStyle get display => GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: NzColors.ink,
      );

  static TextStyle get title => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: NzColors.ink,
      );

  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: NzColors.inkSoft,
      );

  static TextStyle get label => GoogleFonts.nunito(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: NzColors.muted,
      );

  static TextStyle get cheer => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: NzColors.fern,
      );
}

/// Milestone thresholds + scenic unlock labels.
abstract final class NzMilestones {
  static const thresholds = [0.25, 0.50, 0.75, 1.0];

  static String scenicLabel(double pct) {
    if (pct >= 1.0) return 'Southern night sky';
    if (pct >= 0.75) return 'Fjord coast';
    if (pct >= 0.50) return 'Snowy peaks';
    if (pct >= 0.25) return 'Turquoise lake';
    return 'Home hills';
  }

  static String scenicEmoji(double pct) {
    if (pct >= 1.0) return '✨';
    if (pct >= 0.75) return '🏞️';
    if (pct >= 0.50) return '🏔️';
    if (pct >= 0.25) return '🌊';
    return '🌿';
  }

  static String celebrateMessage(double pct) {
    if (pct >= 1.0) return "You're ready for New Zealand!";
    if (pct >= 0.75) return 'Fjord vibes unlocked — almost there!';
    if (pct >= 0.50) return 'Halfway to the mountains!';
    if (pct >= 0.25) return 'First lake unlocked — adventure brewing!';
    return 'The journey begins…';
  }

  /// Return newly crossed milestone (0.25/0.5/0.75/1.0) or null.
  static double? crossed(double before, double after) {
    for (final t in thresholds) {
      if (before < t && after >= t) return t;
    }
    return null;
  }
}

abstract final class NzCopy {
  static String encouraging({
    required double packedPct,
    required int remaining,
    required String meLabel,
    required String catLabel,
    required double mePct,
    required double catPct,
  }) {
    if (packedPct >= 1.0) {
      return "Suitcases closed — New Zealand is calling! 🥝";
    }
    if (remaining <= 3 && remaining > 0) {
      return '$remaining more and you\'re set for the fjords! 🏔️';
    }
    if (packedPct >= 0.75) {
      return 'Almost adventure-ready! 🏔️';
    }
    if (catPct > mePct + 0.08) {
      return "$catLabel's crushing the packing 💪";
    }
    if (mePct > catPct + 0.08) {
      return "$meLabel's on a roll — keep it going!";
    }
    if (packedPct >= 0.5) {
      return 'Halfway packed — the campervan is warming up!';
    }
    if (packedPct >= 0.25) {
      return 'Nice start — every tick gets you closer ✈️';
    }
    return 'Let\'s get adventure-ready together 🌿';
  }

  static String tickCheer(bool packed) =>
      packed ? 'In the suitcase! 🎒' : 'Bought ✓ shopping win!';
}

/// Shared form / sheet / dialog chrome for every NZ trip action surface.
abstract final class NzChrome {
  static const danger = Color(0xFFC45C4A);

  static InputDecoration input(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: NzColors.card,
      isDense: true,
      labelStyle: NzType.label.copyWith(fontSize: 12, color: NzColors.muted),
      hintStyle: NzType.body.copyWith(color: NzColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NzColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NzColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NzColors.fern, width: 1.6),
      ),
    );
  }

  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: NzColors.fern,
        onPrimary: Colors.white,
        secondary: NzColors.lake,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: NzColors.card,
        onSurface: NzColors.ink,
      ),
      scaffoldBackgroundColor: NzColors.snow,
      canvasColor: NzColors.card,
      dividerColor: NzColors.cardBorder,
      textTheme: base.textTheme.apply(
        bodyColor: NzColors.inkSoft,
        displayColor: NzColors.ink,
        fontFamily: GoogleFonts.nunito().fontFamily,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NzColors.card,
        isDense: true,
        labelStyle: NzType.label.copyWith(fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NzColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NzColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NzColors.fern, width: 1.6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return NzColors.fern;
          return NzColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return NzColors.fernLight.withValues(alpha: 0.55);
          }
          return NzColors.cardBorder;
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NzColors.fern,
          foregroundColor: Colors.white,
          textStyle: NzType.title.copyWith(fontSize: 14, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NzColors.fern,
          textStyle: NzType.label.copyWith(fontSize: 13),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NzColors.night,
        contentTextStyle: NzType.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: NzColors.card,
        headerBackgroundColor: NzColors.fern,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.all(NzColors.ink),
        todayForegroundColor: WidgetStateProperty.all(NzColors.fern),
        todayBackgroundColor: WidgetStateProperty.all(
          NzColors.fern.withValues(alpha: 0.15),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NzColors.snow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NzColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: NzType.title.copyWith(fontSize: 17),
        contentTextStyle: NzType.body,
      ),
    );
  }
}
