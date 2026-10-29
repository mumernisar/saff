import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/wake_flow_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// The reveal: ranked list, first waker, streak (`docs/PRODUCT.md` §6.5).
class RevealView extends ConsumerWidget {
  /// Creates the view.
  const RevealView({required this.morning, required this.onExit, super.key});

  /// The morning.
  final MorningKey morning;

  /// Go to chat.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(wakeFlowProvider(morning));
    final vm = ref.read(wakeFlowProvider(morning).notifier);
    final reveal = state.reveal;
    final uid = ref.watch(uidProvider).value ?? '';
    if (reveal == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final firstWaker = reveal.rows
        .where((r) => r.uid == reveal.firstWaker)
        .firstOrNull;
    final me = reveal.rows.where((r) => r.uid == uid).firstOrNull;
    final anyMissed = reveal.rows.any((r) => !r.played);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.revealTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.lg),
        children: [
          if (reveal.solo)
            Text(
              l10n.soloMorning,
              style: TextStyle(color: c.muted),
              textAlign: TextAlign.center,
            ),
          for (final r in reveal.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: SaffSpacing.md),
              child: SaffCard(
                color: r.rank == 1 && !reveal.solo ? c.soft : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        r.rank == 0 ? '–' : '${r.rank}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SaffAvatar(name: r.name, colorIndex: r.avatarColor),
                    const SizedBox(width: SaffSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.uid == uid ? l10n.you : r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            !r.played
                                ? l10n.didNotPlay
                                : r.offlineFallback
                                ? l10n.playedOffline
                                : l10n.correctOf(r.correct, r.total),
                            style: TextStyle(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    if (r.played && !r.offlineFallback)
                      Text(
                        '${r.points}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text('—', style: TextStyle(color: c.muted, fontSize: 24)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: SaffSpacing.md),
          if (firstWaker != null && reveal.rows.length > 1)
            Text(
              firstWaker.uid == uid
                  ? l10n.youWokeFirst
                  : l10n.wokeFirst(firstWaker.name),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SaffSpacing.sm),
            child: Text(
              reveal.streak > 0
                  ? l10n.streakDays(reveal.streak)
                  : (anyMissed ? l10n.streakReset : ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          if (me != null && me.played && !me.offlineFallback)
            Padding(
              padding: const EdgeInsets.only(top: SaffSpacing.md),
              child: PrimaryButton(
                label: l10n.seeTheCards,
                onPressed: vm.openReview,
              ),
            ),
          const SizedBox(height: SaffSpacing.sm),
          OutlinedButton(onPressed: onExit, child: Text(l10n.goToChat)),
        ],
      ),
    );
  }
}
