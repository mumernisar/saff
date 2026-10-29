import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';

/// Welcome and sign-in. Google and email-link sign-in need console setup
/// (SHA-1, dynamic links); until then the dev flavor signs in as a seeded
/// test user (`docs/DEV_RELAXATIONS.md` R-2).
class WelcomeView extends ConsumerWidget {
  /// Creates the view.
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(authViewModelProvider);
    final vm = ref.read(authViewModelProvider.notifier);
    final isDev = ref.watch(environmentConfigProvider).isDev;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SaffSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.wb_twilight, size: 72, color: c.accent),
              const SizedBox(height: SaffSpacing.lg),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: SaffSpacing.sm),
              Text(
                l10n.welcomeBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: c.muted),
              ),
              const Spacer(),
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: SaffSpacing.md),
                  child: Text(
                    failureText(l10n, state.failure!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.error),
                  ),
                ),
              if (isDev) ...[
                Text(
                  l10n.devSignInAs,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: SaffSpacing.sm),
                for (final name in const ['Hamza', 'Ali', 'Sara'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: SaffSpacing.sm),
                    child: PrimaryButton(
                      label: name,
                      loading: state.running,
                      onPressed: () => vm.signInTestUser(name),
                    ),
                  ),
              ] else
                Text(
                  l10n.signInUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
              const SizedBox(height: SaffSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
