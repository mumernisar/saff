import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/wake_flow_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_app/shared/format.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// After finishing: who is still asleep, ring again, call on WhatsApp
/// (`docs/PRODUCT.md` §6.4, frames 3a–3c).
class WaitingView extends ConsumerStatefulWidget {
  /// Creates the view.
  const WaitingView({required this.morning, required this.onExit, super.key});

  /// The morning.
  final MorningKey morning;

  /// Leaves the flow.
  final VoidCallback onExit;

  @override
  ConsumerState<WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends ConsumerState<WaitingView> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
    final c = context.saff;
    final state = ref.watch(wakeFlowProvider(widget.morning));
    final vm = ref.read(wakeFlowProvider(widget.morning).notifier);
    final uid = ref.watch(uidProvider).value ?? '';
    final constants = ref.watch(environmentConfigProvider).constants;
    final round = state.round;
    final others = [
      for (final m in state.members)
        if (m.uid != uid && (round?.requiredIds.contains(m.uid) ?? true)) m,
    ];
    final deadline = round?.deadlineAt;
    final until = deadline?.difference(DateTime.now().toUtc());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.waitingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.lg),
        children: [
          Text(
            l10n.yourScoreLocked,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(l10n.scoresRevealTogether, style: TextStyle(color: c.muted)),
          const SizedBox(height: SaffSpacing.lg),
          if (state.failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SaffSpacing.md),
              child: Text(
                failureText(l10n, state.failure!),
                style: TextStyle(color: c.error),
              ),
            ),
          for (final m in others)
            Builder(
              builder: (_) {
                final status = state.presence[m.uid] ?? LiveStatus.asleep;
                final sent = state.nudges[m.uid];
                final since = sent?.last == null
                    ? null
                    : DateTime.now().difference(sent!.last!);
                final ready = since == null || since >= constants.nudgeInterval;
                final nextIn = since == null
                    ? Duration.zero
                    : constants.nudgeInterval - since;
                final left = constants.nudgesPerTarget - (sent?.count ?? 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: SaffSpacing.md),
                  child: SaffCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SaffAvatar(
                              name: m.displayName,
                              colorIndex: m.avatarColor,
                              status: _toMember(status),
                            ),
                            const SizedBox(width: SaffSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    _statusText(l10n, status),
                                    style: TextStyle(color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (status == LiveStatus.offline)
                          Padding(
                            padding: const EdgeInsets.only(top: SaffSpacing.sm),
                            child: Text(
                              l10n.offlineAlert(m.displayName),
                              style: TextStyle(color: c.error),
                            ),
                          ),
                        if (status != LiveStatus.done &&
                            status != LiveStatus.playing &&
                            status != LiveStatus.missed) ...[
                          const SizedBox(height: SaffSpacing.md),
                          Row(
                            children: [
                              if (status != LiveStatus.offline)
                                Expanded(
                                  child: FilledButton(
                                    key: ValueKey('nudge-${m.uid}'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                    onPressed: left > 0 && ready
                                        ? () => unawaited(vm.nudge(m.uid))
                                        : null,
                                    child: Text(
                                      left <= 0
                                          ? l10n.noRingsLeft
                                          : ready
                                          ? l10n.ringAgain(m.displayName)
                                          : l10n.ringAgainIn(
                                              nextIn.inSeconds + 1,
                                            ),
                                    ),
                                  ),
                                ),
                              if (status != LiveStatus.offline)
                                const SizedBox(width: SaffSpacing.sm),
                              Expanded(
                                child: status == LiveStatus.offline
                                    ? FilledButton.icon(
                                        icon: const Icon(Icons.call),
                                        label: Text(l10n.callOnWhatsapp),
                                        onPressed: () => _wa(m),
                                      )
                                    : OutlinedButton.icon(
                                        icon: const Icon(Icons.call),
                                        label: Text(l10n.callOnWhatsapp),
                                        onPressed: () => _wa(m),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          if (until != null && !until.isNegative)
            Padding(
              padding: const EdgeInsets.only(top: SaffSpacing.md),
              child: Text(
                l10n.revealAt(clock(deadline!)),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _wa(Member m) => launchUrl(
    Uri.parse('https://wa.me/${m.whatsapp.replaceAll('+', '')}'),
    mode: LaunchMode.externalApplication,
  );

  MemberStatus _toMember(LiveStatus s) => switch (s) {
    LiveStatus.asleep => MemberStatus.asleep,
    LiveStatus.snoozed => MemberStatus.snoozed,
    LiveStatus.playing => MemberStatus.playing,
    LiveStatus.done => MemberStatus.done,
    LiveStatus.offline => MemberStatus.offline,
    LiveStatus.missed => MemberStatus.missed,
  };

  String _statusText(AppLocalizations l10n, LiveStatus s) => switch (s) {
    LiveStatus.asleep => l10n.statusAsleep,
    LiveStatus.snoozed => l10n.statusSnoozed,
    LiveStatus.playing => l10n.statusPlaying,
    LiveStatus.done => l10n.statusDone,
    LiveStatus.offline => l10n.statusOffline,
    LiveStatus.missed => l10n.statusMissed,
  };
}
