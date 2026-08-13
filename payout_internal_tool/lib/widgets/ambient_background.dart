import 'package:flutter/material.dart';

import '../theme/hud_decor.dart';

/// Light research-bench canvas with a faint technical grid.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TechGridBackground(child: child);
  }
}
