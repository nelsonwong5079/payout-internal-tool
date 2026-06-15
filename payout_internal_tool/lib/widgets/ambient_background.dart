import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Flat canvas — no gradients or decorative glow.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: child,
    );
  }
}
