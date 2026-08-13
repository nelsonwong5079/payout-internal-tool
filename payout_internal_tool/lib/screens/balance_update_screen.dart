import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payout_balance_service.dart';
import '../theme/app_theme.dart';
import '../theme/hud_decor.dart';
import '../widgets/glass_surface.dart';
import '../widgets/status_pill.dart';

/// Sandbox Balance Update — CSV email + scheduler ping via Cloud Functions.
class BalanceUpdateScreen extends StatefulWidget {
  const BalanceUpdateScreen({super.key});

  @override
  State<BalanceUpdateScreen> createState() => _BalanceUpdateScreenState();
}

class _BalanceUpdateScreenState extends State<BalanceUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretCtrl = TextEditingController();
  final _partnerCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _creditCtrl = TextEditingController();
  final _service = PayoutBalanceService();

  bool _obscureSecret = true;
  bool _obscureApiKey = true;
  bool _loading = false;
  BalanceUpdateResult? _result;

  @override
  void dispose() {
    _secretCtrl.dispose();
    _partnerCtrl.dispose();
    _apiKeyCtrl.dispose();
    _balanceCtrl.dispose();
    _currencyCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final result = await _service.balanceUpdate(
      secret: _secretCtrl.text.trim(),
      partnerId: _partnerCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      balanceValue: num.parse(_balanceCtrl.text.trim()),
      currency: _currencyCtrl.text.trim().toUpperCase(),
      creditLimit: num.parse(_creditCtrl.text.trim()),
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
                Text('// UPDATE', style: AppTypography.label),
                const SizedBox(height: 4),
                Text('Balance Update', style: AppTypography.display),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Builds an AES-zipped balance CSV, emails QA, waits ~15s, '
                  'then pings the scheduler. All signing/SMTP runs on the backend.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    border: Border.all(color: AppColors.ink, width: 1.25),
                  ),
                  child: Text(
                    'Note: Payout Balance uses an intentional ±100 baseline '
                    'offset (not a bug). Example: 80 → "-20", 150 → "+50".',
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _balanceCtrl,
                  enabled: !_loading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Balance value'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (num.tryParse(v.trim()) == null) return 'Must be numeric';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _currencyCtrl,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    hintText: 'USD',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Za-z]+$').hasMatch(v.trim())) {
                      return 'Alphabetic only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _creditCtrl,
                  enabled: !_loading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Credit limit'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (num.tryParse(v.trim()) == null) return 'Must be numeric';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Working (~15s wait)…',
                                style: AppTypography.title.copyWith(
                                  fontSize: 13,
                                  color: AppColors.onInk,
                                ),
                              ),
                            ],
                          )
                        : const Text('Update balance'),
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
                    const Spacer(),
                    if (_result!.zipName != null &&
                        _result!.zipName!.isNotEmpty)
                      Text(
                        _result!.zipName!,
                        style: AppTypography.mono(size: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_result!.message != null)
                  Text(
                    _result!.message!,
                    style: AppTypography.body.copyWith(
                      color: _result!.success
                          ? AppColors.ink
                          : AppColors.error,
                    ),
                  ),
                if (_result!.payoutBalance != null &&
                    _result!.payoutBalance!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Payout Balance field: ${_result!.payoutBalance}',
                    style: AppTypography.mono(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _stepRow('CSV built', _result!.steps.csvBuilt),
                _stepRow('AES zip built', _result!.steps.zipBuilt),
                _stepRow('Email sent', _result!.steps.emailSent),
                _stepRow('Scheduler ack (204)', _result!.steps.schedulerAck),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: ok ? AppColors.success : AppColors.textMutedOnDark,
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
