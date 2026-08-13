import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/hud_decor.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.dark = true,
    this.trailing,
    this.monoTag,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool dark;
  final Widget? trailing;
  final String? monoTag;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HudDecor.statusTrack(height: 8),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  color: AppColors.accent,
                  border: Border.all(color: AppColors.ink, width: 1.25),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (monoTag != null) ...[
                    Text(
                      '// ${monoTag!.toUpperCase()}',
                      style: AppTypography.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.textMutedOnDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(title, style: AppTypography.display),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle!, style: AppTypography.body),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
