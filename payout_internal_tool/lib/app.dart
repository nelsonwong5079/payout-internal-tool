import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/coda_payout_jwt_generator_screen.dart';
import 'screens/sandbox_monitoring_screen.dart';
import 'screens/whitelabel_json_screen.dart';
import 'screens/payout_renotify_screen.dart';
import 'screens/public_template_library_page.dart';
import 'theme/app_theme.dart';
import 'widgets/ambient_background.dart';
import 'main.dart' as main_app;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Payout Internal Tool',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        initialRoute: '/',
        routes: {
          '/': (_) => const AuthWrapper(),
          '/templates': (_) => const PublicTemplateLibraryPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        try {
          if (authService.isAuthenticated) {
            return const AuthenticatedApp();
          }
          return const LoginScreen();
        } catch (e) {
          return const LoginScreen();
        }
      },
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.pageTitle,
    required this.subtitle,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String pageTitle;
  final String subtitle;
}

class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({super.key});

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  int _currentIndex = 0;

  static const _destinations = [
    _NavDestination(
      label: 'Payout Tool',
      shortLabel: 'Payout',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      pageTitle: 'Payout Tool',
      subtitle: 'Upload ZIP files and batch-edit transactions',
    ),
    _NavDestination(
      label: 'Sandbox Monitoring',
      shortLabel: 'Payin',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      pageTitle: 'Sandbox Monitoring',
      subtitle: 'Real-time health checks and metrics',
    ),
    _NavDestination(
      label: 'Whitelabel JSON',
      shortLabel: 'JSON',
      icon: Icons.palette_outlined,
      selectedIcon: Icons.palette,
      pageTitle: 'Whitelabel JSON',
      subtitle: 'Generate synced V1 + V2 theme config',
    ),
    _NavDestination(
      label: 'JWT Generator',
      shortLabel: 'JWT',
      icon: Icons.vpn_key_outlined,
      selectedIcon: Icons.vpn_key,
      pageTitle: 'JWT Generator',
      subtitle: 'Create sandbox payout tokens',
    ),
    _NavDestination(
      label: 'Payout Renotify',
      shortLabel: 'Renotify',
      icon: Icons.notifications_active_outlined,
      selectedIcon: Icons.notifications_active,
      pageTitle: 'Payout Renotify',
      subtitle: 'Resend payout notifications by ID',
    ),
  ];

  final List<Widget> _pages = const [
    main_app.EmailSenderPage(),
    SandboxMonitoringScreen(),
    WhitelabelJsonScreen(),
    CodaPayoutJwtGeneratorScreen(),
    PayoutRenotifyScreen(),
  ];

  void _selectIndex(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          return AmbientBackground(
            child: wide ? _buildWideLayout() : _buildCompactLayout(),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(child: _buildPageArea(showHeader: true)),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Expanded(child: _buildPageArea(showHeader: true)),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildPageArea({bool showHeader = false}) {
    final dest = _destinations[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _buildPageHeader(dest),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _pages[_currentIndex],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader(_NavDestination dest) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        20,
        AppSpacing.page,
        16,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dest.pageTitle,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dest.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildUserMenu(compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 248,
          decoration: const BoxDecoration(
            color: Color(0xB3101012),
            border: Border(right: BorderSide(color: AppColors.glassBorder)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Row(
                    children: [
                      _buildLogoMark(size: 32),
                      const SizedBox(width: 10),
                      Text(
                        'PE Ops',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Tools',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMutedOnDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        _buildSidebarItem(i),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildUserMenu(compact: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.bolt_rounded, color: AppColors.void_, size: size * 0.55),
    );
  }

  Widget _buildSidebarItem(int index) {
    final dest = _destinations[index];
    final selected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectIndex(index),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: selected ? AppColors.surfaceMuted : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? dest.selectedIcon : dest.icon,
                  size: 18,
                  color: selected ? AppColors.textPrimary : AppColors.textMutedOnDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dest.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMenu({required bool compact}) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final email = authService.user?.email ?? 'User';
        final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

        return Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            color: AppColors.surfaceElevated,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.glassBorder),
                color: AppColors.glass,
              ),
              child: Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.surfaceMuted,
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        email.split('@').first,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.unfold_more_rounded,
                        size: 16, color: AppColors.textMutedOnDark),
                  ],
                ],
              ),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await authService.signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                height: 36,
                child: Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text('Sign out', style: GoogleFonts.inter(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xCC101012),
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(child: _buildBottomNavItem(i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index) {
    final dest = _destinations[index];
    final selected = _currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectIndex(index),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: selected ? AppColors.surfaceMuted : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                size: 20,
                color: selected ? AppColors.textPrimary : AppColors.textMutedOnDark,
              ),
              const SizedBox(height: 4),
              Text(
                dest.shortLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? AppColors.textPrimary : AppColors.textMutedOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
