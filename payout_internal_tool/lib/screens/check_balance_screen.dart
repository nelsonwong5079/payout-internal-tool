import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payout_balance_service.dart';
import '../theme/app_theme.dart';
import '../theme/hud_decor.dart';
import '../widgets/glass_surface.dart';
import '../widgets/status_pill.dart';

/// Sandbox / Production Check Balance form.
/// Credentials are POSTed to Cloud Functions; JWT is minted server-side only.
class CheckBalanceScreen extends StatefulWidget {
  const CheckBalanceScreen({super.key});

  @override
  State<CheckBalanceScreen> createState() => _CheckBalanceScreenState();
}

class _CheckBalanceScreenState extends State<CheckBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretCtrl = TextEditingController();
  final _partnerCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _service = PayoutBalanceService();

  bool _production = false;
  bool _obscureSecret = true;
  bool _obscureApiKey = true;
  bool _loading = false;
  CheckBalanceResult? _result;

  @override
  void dispose() {
    _secretCtrl.dispose();
    _partnerCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final result = await _service.checkBalance(
      secret: _secretCtrl.text.trim(),
      partnerId: _partnerCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      production: _production,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.page,
      ),
      children: [
        HudDecor.statusTrack(height: 7),
        const SizedBox(height: AppSpacing.md),
        GlassSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('// BALANCE', style: AppTypography.label),
                const SizedBox(height: 4),
                Text('Check Balance', style: AppTypography.display),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'JWT is signed on the backend. Secret & API key never call '
                  'the payout host from the browser.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _production ? 'Production' : 'Sandbox',
                    style: AppTypography.title.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    _production
                        ? 'payout.codapayments.com/balance'
                        : 'payout.codapayments-staging.com/balance',
                    style: AppTypography.mono(size: 11),
                  ),
                  value: _production,
                  activeTrackColor: AppColors.accent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _production = v),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _secretCtrl,
                  obscureText: _obscureSecret,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: 'Secret',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureSecret = !_obscureSecret),
                      icon: Icon(
                        _obscureSecret
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _partnerCtrl,
                  enabled: !_loading,
                  decoration: const InputDecoration(labelText: 'Partner ID'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureApiKey,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check balance'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.lg),
          GlassSurface(
            selected: _result!.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: _result!.success ? 'OK' : 'ERROR',
                      tone: _result!.success
                          ? StatusPillTone.success
                          : StatusPillTone.error,
                    ),
                    const SizedBox(width: 8),
                    if (_result!.environment != null)
                      Text(
                        (_result!.environment ?? '').toUpperCase(),
                        style: AppTypography.mono(size: 11),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Copy JSON',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _result!.prettyJson()),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied response JSON')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
                if (!_result!.success && _result!.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _result!.message!,
                    style: AppTypography.body.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    border: Border.all(color: AppColors.ink, width: 1),
                  ),
                  child: SelectableText(
                    _result!.prettyJson(),
                    style: AppTypography.mono(size: 12, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
