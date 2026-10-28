import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/ringing_view_model.dart';
import 'package:saff_app/features/wake/widgets/hold_to_start_button.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// The screen the alarm activity shows while the alarm rings.
class RingingView extends ConsumerStatefulWidget {
  /// Creates the view.
  const RingingView({super.key});

  @override
  ConsumerState<RingingView> createState() => _RingingViewState();
}

class _RingingViewState extends ConsumerState<RingingView> {
  late final Timer _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(ringingProvider.notifier).load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(alarmRepositoryProvider).reportWakeReady());
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ringingProvider);
    final vm = ref.read(ringingProvider.notifier);
    final ring = state.ring;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1524),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                DateFormat.Hm().format(_now),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEEF1F6),
                ),
              ),
              Text(
                ring?.alarmName ?? l10n.ringingNoAlarm,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Color(0xFFF2B33D)),
              ),
              const Spacer(),
              if (state.started)
                Text(
                  l10n.ringingStarted,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                )
              else if (ring != null) ...[
                HoldToStartButton(
                  label: l10n.holdToStart,
                  onCompleted: () => unawaited(vm.start()),
                ),
                const SizedBox(height: 16),
                if (!state.snoozed)
                  TextButton(
                    onPressed: () => unawaited(
                      vm.snooze(
                        ref
                            .read(environmentConfigProvider)
                            .constants
                            .snoozeDuration
                            .inMinutes,
                      ),
                    ),
                    child: Text(
                      l10n.snooze,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
