import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Subtle static backdrop — quiet and modern, no grid or heavy animation.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.showGrid = false,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF09090B),
                Color(0xFF0C0C0F),
                Color(0xFF09090B),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.9),
              radius: 1.2,
              colors: [
                AppColors.accent.withValues(alpha: 0.07),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, 0.8),
              radius: 0.9,
              colors: [
                AppColors.violet.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
