import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/features/settings/view_models/settings_view_models.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';

/// Per-category notification switches. Nudges and alarm-critical items are
/// locked on (`docs/PRODUCT.md` §13).
class NotificationSettingsView extends ConsumerWidget {
  /// Creates the view.
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(notificationSettingsProvider).value ?? const {};
    final vm = ref.read(settingsActionsProvider.notifier);
    Widget row(String key, String title) => SwitchListTile(
      title: Text(title),
      value: s[key] ?? true,
      onChanged: (v) => vm.setNotification(key, on: v),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: ListView(
        children: [
          row('proposals', l10n.notifProposals),
          row('chat', l10n.notifChat),
          row('reveal', l10n.notifReveal),
          row('reminders', l10n.notifReminders),
          SwitchListTile(
            title: Text(l10n.notifCritical),
            subtitle: Text(l10n.notifCriticalBody),
            value: true,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}

/// Theme choice.
class AppearanceView extends ConsumerWidget {
  /// Creates the view.
  const AppearanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final vm = ref.read(themeModeProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeTitle)),
      body: RadioGroup<ThemeMode>(
        groupValue: mode,
        onChanged: (m) => vm.set(m ?? ThemeMode.system),
        child: ListView(
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              title: Text(l10n.themeSystem),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              title: Text(l10n.themeLight),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              title: Text(l10n.themeDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feedback with a note for the team.
class FeedbackView extends ConsumerStatefulWidget {
  /// Creates the view.
  const FeedbackView({super.key});

  @override
  ConsumerState<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends ConsumerState<FeedbackView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(settingsActionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          TextField(
            controller: _text,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(labelText: l10n.feedbackHint),
          ),
          if (state.failure != null)
            Text(
              failureText(l10n, state.failure!),
              style: TextStyle(color: context.saff.error),
            ),
          const SizedBox(height: SaffSpacing.lg),
          PrimaryButton(
            label: l10n.feedbackSend,
            loading: state.running,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref
                  .read(settingsActionsProvider.notifier)
                  .feedback(_text.text);
              if (ok && context.mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.feedbackThanks)),
                );
                context.pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// About, with the content attributions the sources require.
class AboutView extends StatelessWidget {
  /// Creates the view.
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          Text(l10n.aboutBody),
          const SizedBox(height: SaffSpacing.lg),
          Text(
            l10n.attributionsTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SaffSpacing.sm),
          Text(l10n.attributionsBody),
        ],
      ),
    );
  }
}
