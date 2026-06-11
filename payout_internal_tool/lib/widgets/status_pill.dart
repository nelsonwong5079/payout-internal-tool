import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum StatusPillTone { neutral, success, error, info, warning }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusPillTone.neutral,
    this.showDot = true,
  });

  final String label;
  final StatusPillTone tone;
  final bool showDot;

  (Color bg, Color fg) _colors() {
    switch (tone) {
      case StatusPillTone.success:
        return (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
        );
      case StatusPillTone.error:
        return (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        );
      case StatusPillTone.info:
        return (
          AppColors.accent.withValues(alpha: 0.12),
          AppColors.accentHover,
        );
      case StatusPillTone.warning:
        return (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
        );
      case StatusPillTone.neutral:
        return (
          AppColors.surfaceMuted,
          AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
