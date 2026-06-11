import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

class CodaPayoutJwtGeneratorScreen extends StatefulWidget {
  const CodaPayoutJwtGeneratorScreen({super.key});

  @override
  State<CodaPayoutJwtGeneratorScreen> createState() =>
      _CodaPayoutJwtGeneratorScreenState();
}

class _CodaPayoutJwtGeneratorScreenState
    extends State<CodaPayoutJwtGeneratorScreen> {
  late final String _viewType;
  late final String _iframeSrc;

  @override
  void initState() {
    super.initState();

    _viewType =
        'coda-payout-jwt-generator-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _iframeSrc = Uri.base.resolve('jwt-token-generator.html').toString();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = _iframeSrc
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..setAttribute('loading', 'lazy')
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
        ..setAttribute('allow', 'clipboard-write');

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.page,
      ),
      child: GlassSurface(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
