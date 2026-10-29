import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_app/features/settings/view_models/crash_test_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// Settings, pushed over the tabs (`docs/PRODUCT.md` §13). Sections arrive
/// with the stages that own them.
class SettingsView extends ConsumerWidget {
  /// Creates the view.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final crash = ref.watch(crashTestProvider);
    final profile = ref.watch(profileProvider).value;
    final saffs = ref.watch(mySaffsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (profile != null)
            ListTile(
              leading: SaffAvatar(
                name: profile.displayName,
                colorIndex: profile.avatarColor,
                size: 48,
              ),
              title: Text(profile.displayName),
              subtitle: Text(profile.whatsapp),
            ),
          SectionHeader(l10n.settingsSaffs),
          for (final s in saffs)
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(s.name),
              onTap: () => context.push('/saff/${s.id}'),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.startSaff),
            onTap: () => context.push('/saff/new'),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(l10n.joinWithCode),
            onTap: () => context.push('/saff/join'),
          ),
          SectionHeader(l10n.settingsReliability),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: Text(l10n.alarmSetupTitle),
            onTap: () => context.go('/today/settings/alarm'),
          ),
          SectionHeader(l10n.settingsAccount),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),
          if (crash.available)
            ListTile(
              key: const ValueKey('trigger-test-crash'),
              leading: const Icon(Icons.bug_report),
              title: Text(l10n.devTriggerTestCrash),
              onTap: crash.triggerTestCrash,
            ),
        ],
      ),
    );
  }
}
