import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_bootstrap.dart';
import 'screens/login_screen.dart';
import 'screens/coda_payout_jwt_generator_screen.dart';
import 'screens/sandbox_monitoring_screen.dart';
import 'screens/whitelabel_json_screen.dart';
import 'screens/payout_renotify_screen.dart';
import 'screens/coda_hosted_card_screen.dart';
import 'screens/check_balance_screen.dart';
import 'screens/balance_update_screen.dart';
import 'screens/public_template_library_page.dart';
import 'screens/nz_trip/nz_trip_gate.dart';
import 'screens/nz_trip/nz_trip_page.dart';
import 'theme/app_theme.dart';
import 'theme/hud_decor.dart';
import 'widgets/ambient_background.dart';
import 'main.dart' as main_app;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  configureFirestoreForWeb();
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
          // Obscure bookmark path + PIN gate (see nz_trip_gate.dart).
          kNzTripRoute: (_) => const NzTripPage(),
          // Old guessable path — send nowhere useful.
          '/nz-trip': (_) => const _SilentHomeRedirect(),
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

/// Old `/nz-trip` bookmarks land on login with no hint.
class _SilentHomeRedirect extends StatefulWidget {
  const _SilentHomeRedirect();

  @override
  State<_SilentHomeRedirect> createState() => _SilentHomeRedirectState();
}

class _SilentHomeRedirectState extends State<_SilentHomeRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.shortLabel,
    required this.engTag,
    required this.icon,
    required this.selectedIcon,
    required this.pageTitle,
    required this.subtitle,
  });

  final String label;
  final String shortLabel;
  /// Decorative mono tag only (e.g. PAYOUT) — not used for routing.
  final String engTag;
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
      engTag: 'PAYOUT',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      pageTitle: 'Payout Tool',
      subtitle: 'Upload ZIP files and batch-edit transactions',
    ),
    _NavDestination(
      label: 'Sandbox Monitoring',
      shortLabel: 'Payin',
      engTag: 'MONITOR',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      pageTitle: 'Sandbox Monitoring',
      subtitle: 'Real-time health checks and metrics',
    ),
    _NavDestination(
      label: 'Whitelabel JSON',
      shortLabel: 'JSON',
      engTag: 'THEME',
      icon: Icons.palette_outlined,
      selectedIcon: Icons.palette,
      pageTitle: 'Whitelabel JSON',
      subtitle: 'Generate synced V1 + V2 theme config',
    ),
    _NavDestination(
      label: 'JWT Generator',
      shortLabel: 'JWT',
      engTag: 'TOKEN',
      icon: Icons.vpn_key_outlined,
      selectedIcon: Icons.vpn_key,
      pageTitle: 'JWT Generator',
      subtitle: 'Create sandbox payout tokens',
    ),
    _NavDestination(
      label: 'Payout Renotify',
      shortLabel: 'Renotify',
      engTag: 'NOTIFY',
      icon: Icons.notifications_active_outlined,
      selectedIcon: Icons.notifications_active,
      pageTitle: 'Payout Renotify',
      subtitle: 'Resend payout notifications by ID',
    ),
    _NavDestination(
      label: 'Hosted Card',
      shortLabel: 'Cards',
      engTag: 'CARD',
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card,
      pageTitle: 'Hosted Card',
      subtitle: 'Coda Card Hosted Component checkout + inquiry',
    ),
    _NavDestination(
      label: 'Check Balance',
      shortLabel: 'Balance',
      engTag: 'BALANCE',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      pageTitle: 'Check Balance',
      subtitle: 'Sandbox / production payout balance lookup',
    ),
    _NavDestination(
      label: 'Balance Update',
      shortLabel: 'Update',
      engTag: 'UPDATE',
      icon: Icons.sync_alt_rounded,
      selectedIcon: Icons.sync_alt_rounded,
      pageTitle: 'Balance Update',
      subtitle: 'Email AES balance CSV + ping scheduler (sandbox)',
    ),
  ];

  final List<Widget> _pages = const [
    main_app.EmailSenderPage(),
    SandboxMonitoringScreen(),
    WhitelabelJsonScreen(),
    CodaPayoutJwtGeneratorScreen(),
    PayoutRenotifyScreen(),
    CodaHostedCardScreen(),
    CheckBalanceScreen(),
    BalanceUpdateScreen(),
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
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
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
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: 1.25),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HudDecor.statusTrack(height: 8),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '// ${dest.engTag}',
                            style: AppTypography.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.textMutedOnDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          HudDecor.lamp(on: true),
                          const SizedBox(width: 6),
                          Text(
                            'SYSTEM ONLINE',
                            style: AppTypography.mono(
                              size: 9,
                              weight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(dest.pageTitle, style: AppTypography.display),
                      const SizedBox(height: AppSpacing.xs),
                      Text(dest.subtitle, style: AppTypography.body),
                    ],
                  ),
                ),
                _buildUserMenu(compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(right: BorderSide(color: AppColors.ink, width: 1.25)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildLogoMark(size: 34),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PE Ops', style: AppTypography.title),
                            Text(
                              'FIELD TERMINAL',
                              style: AppTypography.mono(
                                size: 9,
                                weight: FontWeight.w700,
                                color: AppColors.textMutedOnDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  HudDecor.statusTrack(height: 7),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HudDecor.lamp(on: true),
                      const SizedBox(width: 6),
                      Text(
                        'LOCAL CORE',
                        style: AppTypography.mono(
                          size: 9,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      HudDecor.cornerIndex('R / 01'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('// MODULES', style: AppTypography.label),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    _buildSidebarItem(i),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _buildUserMenu(compact: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Icon(Icons.bolt_rounded, color: AppColors.ink, size: size * 0.55),
    );
  }

  Widget _buildSidebarItem(int index) {
    final dest = _destinations[index];
    final selected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectIndex(index),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: selected ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.ink : Colors.transparent,
                width: 1.25,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  color: selected ? AppColors.ink : AppColors.borderHairline,
                ),
                Icon(
                  selected ? dest.selectedIcon : dest.icon,
                  size: 18,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest.label,
                        style: AppTypography.title.copyWith(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      Text(
                        dest.engTag,
                        style: AppTypography.mono(
                          size: 9,
                          weight: FontWeight.w700,
                          color: AppColors.inkSoft,
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
              side: const BorderSide(color: AppColors.ink, width: 1.25),
            ),
            color: AppColors.surfaceElevated,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.sm : 10,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.ink, width: 1.25),
                color: AppColors.surfaceElevated,
              ),
              child: Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      border: Border.all(color: AppColors.ink, width: 1),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Text(
                      initial,
                      style: AppTypography.mono(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OPERATOR',
                            style: AppTypography.mono(
                              size: 8,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            email.split('@').first,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.unfold_more_rounded,
                        size: 16, color: AppColors.ink),
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
                child: Text(email, style: AppTypography.body),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 16, color: AppColors.ink),
                    const SizedBox(width: 10),
                    Text('Sign out', style: AppTypography.title.copyWith(fontSize: 13)),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.ink, width: 1.25)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HudDecor.statusTrack(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(child: _buildBottomNavItem(i)),
                ],
              ),
            ),
          ],
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: selected ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.ink : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                size: 18,
                color: AppColors.ink,
              ),
              const SizedBox(height: 3),
              Text(
                dest.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(
                  size: 8.5,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
