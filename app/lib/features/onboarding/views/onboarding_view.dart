import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// Permissions walkthrough with brand-specific steps and a test alarm.
class OnboardingView extends ConsumerStatefulWidget {
  /// Creates the view.
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(onboardingProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final async = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final s = async.value;
    final r = s?.readiness;
    Widget row(
      String title,
      String body, {
      required bool ok,
      required VoidCallback fix,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: SaffSpacing.md),
      child: SaffCard(
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              color: ok ? c.done : c.muted,
            ),
            const SizedBox(width: SaffSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(body, style: TextStyle(color: c.muted)),
                ],
              ),
            ),
            if (!ok) TextButton(onPressed: fix, child: Text(l10n.alarmFix)),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          Text(l10n.onboardingBody, style: TextStyle(color: c.muted)),
          const SizedBox(height: SaffSpacing.xl),
          if (r != null) ...[
            row(
              l10n.alarmReadinessNotifications,
              l10n.permNotificationsBody,
              ok: r.notificationsAllowed,
              fix: () => unawaited(vm.allowNotifications()),
            ),
            row(
              l10n.alarmReadinessExact,
              l10n.permExactBody,
              ok: r.exactAlarmAllowed,
              fix: () => unawaited(vm.open(ReadinessItem.exactAlarm)),
            ),
            row(
              l10n.alarmReadinessFullScreen,
              l10n.permFullScreenBody,
              ok: r.fullScreenIntentAllowed,
              fix: () => unawaited(vm.open(ReadinessItem.fullScreenIntent)),
            ),
            row(
              l10n.alarmReadinessBattery,
              l10n.permBatteryBody,
              ok: r.batteryOptimisationIgnored,
              fix: () => unawaited(vm.open(ReadinessItem.batteryOptimisation)),
            ),
          ],
          if (s?.guide != null) ...[
            SectionHeader(s!.guide!.title),
            for (var i = 0; i < s.guide!.steps.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: c.soft,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 12, color: c.text),
                  ),
                ),
                title: Text(s.guide!.steps[i]),
              ),
          ],
          const SizedBox(height: SaffSpacing.lg),
          OutlinedButton.icon(
            icon: const Icon(Icons.alarm),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await vm.testAlarm();
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.alarmTestScheduled)),
              );
            },
            label: Text(l10n.alarmTestIn10),
          ),
          const SizedBox(height: SaffSpacing.sm),
          PrimaryButton(
            label: l10n.onboardingDone,
            onPressed: () async {
              await ref.read(onboardedProvider.notifier).finish();
              if (context.mounted) context.go('/today');
            },
          ),
        ],
      ),
    );
  }
}
