import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/features/alarms/view_models/reliability_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Alarm reliability: permission checks, test alarm and the ring log.
class ReliabilityView extends ConsumerStatefulWidget {
  /// Creates the view.
  const ReliabilityView({super.key});

  @override
  ConsumerState<ReliabilityView> createState() => _ReliabilityViewState();
}

class _ReliabilityViewState extends ConsumerState<ReliabilityView>
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
      unawaited(ref.read(reliabilityProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = ref.read(reliabilityProvider.notifier);
    final async = ref.watch(reliabilityProvider);
    final s = async.value;
    final r = s?.readiness;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alarmSetupTitle)),
      body: ListView(
        children: [
          if (r != null) ...[
            _Row(
              l10n.alarmReadinessExact,
              ok: r.exactAlarmAllowed,
              onFix: () => vm.fix(ReadinessItem.exactAlarm),
            ),
            _Row(
              l10n.alarmReadinessFullScreen,
              ok: r.fullScreenIntentAllowed,
              onFix: () => vm.fix(ReadinessItem.fullScreenIntent),
            ),
            _Row(
              l10n.alarmReadinessNotifications,
              ok: r.notificationsAllowed,
              onFix: () => vm.fix(ReadinessItem.notifications),
            ),
            _Row(
              l10n.alarmReadinessBattery,
              ok: r.batteryOptimisationIgnored,
              onFix: () => vm.fix(ReadinessItem.batteryOptimisation),
            ),
          ],
          const Divider(),
          ListTile(
            key: const ValueKey('test-alarm'),
            leading: const Icon(Icons.alarm),
            title: Text(l10n.alarmTestIn10),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await vm.scheduleTest();
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.alarmTestScheduled)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: Text(l10n.alarmRingNow),
            onTap: vm.ringNow,
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(l10n.alarmForceFallback),
            onTap: () => vm.setForceFallback(on: true),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.alarmClearFallback),
            onTap: () => vm.setForceFallback(on: false),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.alarmRingLog),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: vm.refresh,
            ),
          ),
          for (final e in s?.log.reversed ?? const <RingLogEntry>[])
            ListTile(
              dense: true,
              title: Text(
                '${e.occurrenceId}  late ${e.delayMs} ms · sound '
                '${e.soundStartMs} ms · wake ${e.engineReadyMs} ms'
                '${e.usedFallback ? ' · fallback' : ''}',
              ),
              subtitle: e.error == null ? null : Text(e.error!),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, {required this.ok, required this.onFix});

  final String label;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error,
        color: ok ? Colors.green : Colors.red,
      ),
      title: Text(label),
      trailing: ok
          ? Text(l10n.alarmOk)
          : TextButton(onPressed: onFix, child: Text(l10n.alarmFix)),
    );
  }
}
