import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/hud_decor.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_surface.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    try {
      final savedRememberMe = html.window.localStorage['rememberMe'] == 'true';
      if (savedRememberMe) {
        final savedEmail = html.window.localStorage['savedEmail'] ?? '';
        final savedPassword = html.window.localStorage['savedPassword'] ?? '';

        setState(() {
          _rememberMe = true;
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    } catch (_) {}
  }

  void _saveCredentials() {
    try {
      if (_rememberMe) {
        html.window.localStorage['rememberMe'] = 'true';
        html.window.localStorage['savedEmail'] = _emailController.text.trim();
        html.window.localStorage['savedPassword'] = _passwordController.text;
      } else {
        html.window.localStorage['rememberMe'] = '';
        html.window.localStorage['savedEmail'] = '';
        html.window.localStorage['savedPassword'] = '';
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      _saveCredentials();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SafeArea(
              child: wide ? _buildSplitLayout() : _buildStackedLayout(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSplitLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildBrandPanel()),
        Expanded(flex: 4, child: _buildLoginPanel(maxWidth: 420)),
      ],
    );
  }

  Widget _buildStackedLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        children: [
          _buildBrandPanel(compact: true),
          const SizedBox(height: AppSpacing.xl),
          _buildLoginPanel(maxWidth: 440),
        ],
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : AppSpacing.page * 2),
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!compact) ...[
            HudDecor.statusTrack(height: 8),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                HudDecor.lamp(on: true),
                const SizedBox(width: 6),
                Text(
                  'SYSTEM ONLINE',
                  style: AppTypography.mono(
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                HudDecor.cornerIndex('WB / 00.05'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Container(
            width: compact ? 56 : 64,
            height: compact ? 56 : 64,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.ink, width: 1.75),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: AppColors.ink,
              size: compact ? 28 : 32,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
          Text(
            '// ARCHIVE',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: AppTypography.mono(size: 11, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'PE Ops',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: AppTypography.display.copyWith(
              fontSize: compact ? 32 : 42,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Internal tools for Payment Enablement Operations',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: AppTypography.body.copyWith(fontSize: compact ? 14 : 15),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                const _FeatureChip(label: 'Batch processing'),
                const _FeatureChip(label: 'Sandbox monitor'),
                const _FeatureChip(label: 'Theme builder'),
                _FeatureChip(
                  label: 'Template library',
                  onTap: () => Navigator.of(context).pushNamed('/templates'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginPanel({required double maxWidth}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GlassSurface(
            radius: AppRadii.xl,
            padding: const EdgeInsets.all(AppSpacing.page * 1.5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '// ACCESS',
                    style: AppTypography.mono(size: 10, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in',
                    style: AppTypography.display.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Enter your credentials to access internal tools',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.body
                                  .copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@codapayments.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: AppMotion.snap,
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _rememberMe
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 1.25,
                                ),
                              ),
                              child: _rememberMe
                                  ? const Icon(Icons.check,
                                      size: 12, color: AppColors.ink)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text('Remember me', style: AppTypography.body),
                            const Spacer(),
                            const Icon(Icons.shield_outlined,
                                size: 16, color: AppColors.ink),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onInk,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/templates'),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: const Text('Template Library'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No sign-in required',
                    textAlign: TextAlign.center,
                    style: AppTypography.label,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.ink, width: 1.25),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.ink),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Contact nelson.wong@codapayments.com for credentials',
                            style: AppTypography.body.copyWith(
                              fontSize: 12,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.accent : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.ink, width: 1.25),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.mono(
          size: 10,
          weight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: chip,
      ),
    );
  }
}
