import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mode_arcade/mode_arcade.dart';
import 'package:mode_card_duel/mode_card_duel.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/wake_flow_view_model.dart';
import 'package:saff_app/features/wake/views/fallback_game_view.dart';
import 'package:saff_app/features/wake/views/reveal_view.dart';
import 'package:saff_app/features/wake/views/review_view.dart';
import 'package:saff_app/features/wake/views/waiting_view.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_modes/saff_modes.dart';
import 'package:saff_ui/saff_ui.dart';

/// The morning after the alarm is stopped: play → waiting → reveal → review.
class WakeFlowView extends ConsumerWidget {
  /// Creates the view.
  const WakeFlowView({
    required this.saffId,
    required this.occurrenceId,
    required this.onExit,
    super.key,
  });

  /// The saff.
  final String saffId;

  /// The occurrence.
  final String occurrenceId;

  /// Called by "Go to chat" / close.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = (saffId: saffId, occurrenceId: occurrenceId);
    final state = ref.watch(wakeFlowProvider(key));
    final vm = ref.read(wakeFlowProvider(key).notifier);
    final constants = ref.watch(environmentConfigProvider).constants;
    final registry = ModeRegistry([
      ClimberMode(
        ClimberStrings(
          hint: l10n.climberHint,
          reached: l10n.climberReached,
          locked: l10n.climberLocked,
          continueLabel: l10n.continueLabel,
        ),
      ),
      CardDuelMode(
        cardTime: constants.cardSeconds,
        strings: CardDuelStrings(
          cardOf: l10n.cardOf,
          sendAnswer: l10n.sendAnswer,
          typeAnswer: l10n.typeAnswer,
          iKnewIt: l10n.iKnewIt,
          iDidNot: l10n.iDidNot,
          showAnswer: l10n.showAnswer,
          timeUp: l10n.timeUp,
          yourAnswerSaved: l10n.yourScoreLocked,
          fromName: l10n.fromName,
        ),
      ),
    ]);
    switch (state.phase) {
      case WakePhase.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case WakePhase.fallback:
        return FallbackGameView(onDone: vm.onFallbackDone);
      case WakePhase.testDone:
        return Scaffold(
          body: EmptyState(
            title: l10n.testAlarmWorked,
            action: PrimaryButton(label: l10n.done, onPressed: onExit),
          ),
        );
      case WakePhase.play:
        final round = state.round!;
        final mode = registry.create(round.mode);
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                if (mode == null)
                  Center(child: Text(l10n.modeUnsupported))
                else
                  mode.build(
                    context,
                    round,
                    state.answers,
                    ModeCallbacks(
                      onAnswer: vm.onAnswer,
                      onDone: () => unawaited(vm.onDone()),
                      onActivity: vm.onActivity,
                      onScore: vm.onScore,
                    ),
                  ),
                if (state.idle)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(SaffSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.stillWithUs,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: SaffSpacing.xl),
                              PrimaryButton(
                                label: l10n.continueLabel,
                                onPressed: () =>
                                    unawaited(vm.continueAfterIdle()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      case WakePhase.waiting:
        return WaitingView(morning: key, onExit: onExit);
      case WakePhase.reveal:
        return RevealView(morning: key, onExit: onExit);
      case WakePhase.review:
        return ReviewView(morning: key, onExit: onExit);
    }
  }
}
