import 'package:flutter/material.dart';
import 'template_library_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/status_pill.dart';

/// Public template library — no authentication required.
class PublicTemplateLibraryPage extends StatelessWidget {
  const PublicTemplateLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  12,
                  AppSpacing.page,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to sign in',
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Template Library',
                            style: AppTypography.display.copyWith(fontSize: 18),
                          ),
                          Text(
                            'Publisher communication templates — no sign-in required',
                            style: AppTypography.body.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const StatusPill(
                      label: 'Public',
                      tone: StatusPillTone.neutral,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/');
                      },
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.glassBorder),
            const Expanded(child: TemplateLibraryScreen()),
          ],
        ),
      ),
    );
  }
}
