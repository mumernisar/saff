import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/features/settings/view_models/crash_test_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Settings, pushed over the tabs.
class SettingsView extends ConsumerWidget {
  /// Creates the view.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final crash = ref.watch(crashTestProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
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
