import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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

    // Unique viewType prevents collisions with other iframes registered in the app.
    _viewType = 'coda-payout-jwt-generator-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _iframeSrc = Uri.base.resolve('jwt-token-generator.html').toString();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = _iframeSrc
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..setAttribute('loading', 'lazy')
        // This app is for internal testing; allow scripts to run inside the tool.
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
        // Enables `navigator.clipboard.writeText()` inside the embedded page.
        ..setAttribute('allow', 'clipboard-write');

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Coda Payout JWT Generator',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: HtmlElementView(viewType: _viewType),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

