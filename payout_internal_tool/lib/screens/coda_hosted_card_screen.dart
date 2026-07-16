import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

class CodaHostedCardScreen extends StatefulWidget {
  const CodaHostedCardScreen({super.key});

  @override
  State<CodaHostedCardScreen> createState() => _CodaHostedCardScreenState();
}

class _CodaHostedCardScreenState extends State<CodaHostedCardScreen> {
  late final String _viewType;
  late final String _iframeSrc;

  @override
  void initState() {
    super.initState();

    _viewType =
        'coda-hosted-card-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _iframeSrc = Uri.base.resolve('coda-hosted-card.html').toString();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = _iframeSrc
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#09090B'
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..setAttribute('loading', 'eager')
        // 3DS / payment SDK needs scripts, same-origin, forms, and popups/modals.
        ..setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-popups allow-modals allow-popups-to-escape-sandbox',
        )
        ..setAttribute('allow', 'payment *');

      return iframe;
    });
  }

  void _openStandalone() {
    html.window.open(_iframeSrc, '_blank');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GlassSurface(
              padding: EdgeInsets.zero,
              radius: AppRadii.lg,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.credit_card_rounded,
            size: 16,
            color: AppColors.textMutedOnDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Coda Hosted Component (Cards) — init/inquiry proxies, SDK checkout, and live backend debug panel.',
              style: AppTypography.body.copyWith(fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: _openStandalone,
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Open standalone'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: AppTypography.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
