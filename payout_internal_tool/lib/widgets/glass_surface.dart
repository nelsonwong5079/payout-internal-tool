import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Solid elevated panel — no backdrop blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.lg,
    this.width,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double? width;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.panelDecoration(
        radius: radius,
        color: tint ?? AppColors.surfaceElevated,
      ),
      child: child,
    );
  }
}
