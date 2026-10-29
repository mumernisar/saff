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
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: Text(l10n.permissionWalkthrough),
            onTap: () => context.push('/onboarding'),
          ),
          SectionHeader(l10n.settingsApp),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.notificationsTitle),
            onTap: () => context.push('/today/settings/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.themeTitle),
            onTap: () => context.push('/today/settings/appearance'),
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: Text(l10n.feedbackTitle),
            onTap: () => context.push('/today/settings/feedback'),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.aboutTitle),
            onTap: () => context.push('/today/settings/about'),
          ),
          SectionHeader(l10n.settingsAccount),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: context.saff.error),
            title: Text(
              l10n.deleteAccount,
              style: TextStyle(color: context.saff.error),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteAccount),
                  content: Text(l10n.deleteAccountBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.deleteAccount),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(authViewModelProvider.notifier).deleteAccount();
              }
            },
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
