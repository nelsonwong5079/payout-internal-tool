import 'package:flutter/material.dart';
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

  (Color bg, Color fg, Color border) _colors() {
    switch (tone) {
      case StatusPillTone.success:
        return (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          AppColors.success,
        );
      case StatusPillTone.error:
        return (
          AppColors.error.withValues(alpha: 0.1),
          AppColors.error,
          AppColors.error,
        );
      case StatusPillTone.info:
        return (
          AppColors.accent.withValues(alpha: 0.55),
          AppColors.ink,
          AppColors.ink,
        );
      case StatusPillTone.warning:
        return (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
          AppColors.warning,
        );
      case StatusPillTone.neutral:
        return (
          AppColors.surfaceMuted,
          AppColors.inkSoft,
          AppColors.ink,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 0.8),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.mono(
              size: 10,
              weight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
