import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Glass panel used across ops screens.
class OpsSurface extends StatelessWidget {
  const OpsSurface({
    super.key,
    required this.child,
    this.padding,
    this.dark = true,
    this.radius = AppRadii.lg,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool dark;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (dark) {
      return GlassSurface(
        padding: padding ?? const EdgeInsets.all(20),
        radius: radius,
        width: width,
        child: child,
      );
    }

    return Container(
      width: width ?? double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(radius: radius),
      child: child,
    );
  }
}
