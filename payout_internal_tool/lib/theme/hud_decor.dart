import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Purely decorative research-workbench chrome (no behavior).
/// Kept paint-cheap for Flutter web (no full-screen CustomPaint).
abstract final class HudDecor {
  /// Yellow status track — solid bar (CSS-cheap; no CustomPaint).
  static Widget statusTrack({double height = 8}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: 1),
          bottom: BorderSide(color: AppColors.ink, width: 1),
        ),
      ),
    );
  }

  /// Mono system tag, e.g. `// DATA` or `REC 03`.
  static Widget codeTag(String text, {Color? color, bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.accent : Colors.transparent,
        border: Border.all(color: AppColors.ink, width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.mono(
          size: 9.5,
          weight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }

  /// Small status lamp.
  static Widget lamp({bool on = true, Color? color}) {
    final c = color ?? (on ? AppColors.accent : AppColors.borderSubtle);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 1),
      ),
    );
  }

  /// Corner index badge, e.g. `WB / 00.05`.
  static Widget cornerIndex(String code) {
    return Text(
      code,
      style: AppTypography.mono(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textMutedOnDark,
      ),
    );
  }

  /// Panel header: title + // tag + optional index.
  static Widget panelCaption({
    required String title,
    String? engTag,
    String? index,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (engTag != null) ...[
                Text(
                  '// $engTag',
                  style: AppTypography.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.textMutedOnDark,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(title, style: AppTypography.title),
            ],
          ),
        ),
        if (index != null) cornerIndex(index),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }
}

/// Solid paper canvas — no full-viewport line grid (that was janky on web).
class TechGridBackground extends StatelessWidget {
  const TechGridBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: child,
    );
  }
}
