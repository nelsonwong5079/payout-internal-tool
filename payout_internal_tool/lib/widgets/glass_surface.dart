import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.lg,
    this.width,
    this.blur = 8,
    this.glow = false,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double? width;
  final double blur;
  final bool glow;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width ?? double.infinity,
          padding: padding ?? const EdgeInsets.all(AppSpacing.card),
          decoration: AppTheme.glassDecoration(
            radius: radius,
            tint: tint,
            glow: glow,
          ),
          child: child,
        ),
      ),
    );
  }
}
