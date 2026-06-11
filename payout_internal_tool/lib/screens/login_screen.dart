import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_surface.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _typingController;
  late AnimationController _rippleController;
  late AnimationController _floatingController;
  late AnimationController _glowController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _typingAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _glowAnimation;

  // Floating particles
  final List<_FloatingParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    // Setup animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _typingController.repeat(reverse: true);
    _rippleController.repeat();
    _floatingController.repeat();
    _glowController.repeat(reverse: true);
    
    // Initialize floating particles
    _initializeParticles();
    
    // Load saved credentials if "Remember Me" was checked
    _loadSavedCredentials();
  }

  void _initializeParticles() {
    for (int i = 0; i < 15; i++) {
      _particles.add(_FloatingParticle());
    }
  }

  // Load saved credentials from localStorage
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
    } catch (e) {
      // Error handling without print statements
    }
  }

  // Save credentials to localStorage
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
    } catch (e) {
      // Error handling without print statements
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _typingController.dispose();
    _rippleController.dispose();
    _floatingController.dispose();
    _glowController.dispose();
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
      
      // Save credentials if "Remember Me" is checked
      _saveCredentials();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildBrandPanel(compact: true),
          const SizedBox(height: 32),
          _buildLoginPanel(maxWidth: 440),
        ],
      ),
    );
  }

  Widget _buildBrandPanel({bool compact = false}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.all(compact ? 0 : 48),
        child: Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 56 : 64,
              height: compact ? 56 : 64,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: AppColors.void_,
                size: compact ? 28 : 32,
              ),
            ),
            SizedBox(height: compact ? 20 : 32),
            Text(
              'PE Ops',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.inter(
                fontSize: compact ? 32 : 40,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Internal tools for Payment Enablement Operations',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.inter(
                fontSize: compact ? 15 : 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _FeatureChip(label: 'Batch processing'),
                  const _FeatureChip(label: 'Sandbox monitor'),
                  const _FeatureChip(label: 'Theme builder'),
                  _FeatureChip(
                    label: 'Template library',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/templates'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPanel({required double maxWidth}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: GlassSurface(
                radius: AppRadii.xxl,
                glow: true,
                padding: const EdgeInsets.all(36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your credentials to access internal tools',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
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
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border:
                                  Border.all(color: AppColors.glassBorder),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    gradient: _rememberMe
                                        ? AppTheme.brandGradient
                                        : null,
                                    color: _rememberMe
                                        ? null
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _rememberMe
                                          ? Colors.transparent
                                          : AppColors.textMutedOnDark,
                                    ),
                                  ),
                                  child: _rememberMe
                                      ? const Icon(Icons.check,
                                          size: 14, color: AppColors.void_)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Remember me',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.shield_outlined,
                                    size: 16,
                                    color: AppColors.textMutedOnDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                        SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.void_,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/templates'),
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('Template Library'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No sign-in required',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMutedOnDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: AppColors.textMutedOnDark),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Contact nelson.wong@codapayments.com for credentials',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.surfaceMuted : AppColors.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onTap != null
              ? AppColors.accent.withValues(alpha: 0.35)
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: onTap != null ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

// Floating particle class
class _FloatingParticle {
  final double x = math.Random().nextDouble();
  final double y = math.Random().nextDouble();
  final double size = math.Random().nextDouble() * 3 + 1;
  final double speed = math.Random().nextDouble() * 0.3 + 0.05;
  final double angle = math.Random().nextDouble() * 2 * math.pi;
}

// Custom painter for floating particles
class _FloatingParticlesPainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final Animation<double> animation;

  _FloatingParticlesPainter({
    required this.particles,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final x = (particle.x + animation.value * particle.speed) * size.width;
      final y = (particle.y + math.sin(animation.value * 2 * math.pi + particle.angle) * 20) * size.height;
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 