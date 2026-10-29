import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/alarms/view_models/proposal_view_model.dart';
import 'package:saff_app/features/alarms/widgets/propose_sheet.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// A proposal in chat with Accept / Suggest another time / No
/// (`docs/design/flows.md` frames 6b, 6d).
class ProposalCard extends ConsumerWidget {
  /// Creates the card.
  const ProposalCard({
    required this.saffId,
    required this.proposal,
    required this.proposerName,
    required this.members,
    super.key,
  });

  /// The saff.
  final String saffId;

  /// The proposal.
  final Proposal proposal;

  /// Proposer's display name.
  final String proposerName;

  /// Members of the saff.
  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final uid = ref.watch(uidProvider).value ?? '';
    final p = proposal;
    final name = '${p.payload['name'] ?? ''}';
    final time = '${p.payload['time'] ?? ''}';
    final days = ((p.payload['days'] as List?) ?? const []).cast<int>();
    final saff = ref
        .watch(mySaffsProvider)
        .value
        ?.where((s) => s.id == saffId)
        .firstOrNull;
    final isPair = saff?.isPair ?? true;
    final mine = p.proposerId == uid;
    final voted = p.acceptedIds.contains(uid);
    final eligible = p.requiredIds.isEmpty || p.requiredIds.contains(uid);
    final canVote = p.isPending && !mine && !voted && eligible;
    final joinable =
        !isPair &&
        p.type == ProposalType.alarmCreate &&
        p.status == 'accepted' &&
        !voted;
    final headline = switch (p.type) {
      ProposalType.alarmCreate => l10n.proposedAlarm(proposerName),
      ProposalType.alarmChange => l10n.proposedChange(proposerName),
      ProposalType.alarmDelete => l10n.proposedDelete(proposerName),
    };
    final statusText = switch (p.status) {
      'accepted' => l10n.proposalAccepted,
      'declined' => l10n.proposalDeclined,
      'superseded' => l10n.proposalSuperseded,
      'expired' => l10n.proposalExpired,
      _ => null,
    };
    final vm = ref.read(proposalViewModelProvider.notifier);

    Future<void> vote({required bool accept}) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await vm.vote(saffId, p.id, accept: accept);
      if (!ok) {
        final f = ref.read(proposalViewModelProvider).failure;
        if (f != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureText(l10n, f))),
          );
        }
      }
    }

    final waiting = [
      for (final m in members)
        if (p.requiredIds.contains(m.uid) && !p.acceptedIds.contains(m.uid))
          m.displayName,
    ];
    return SaffCard(
      color: c.soft,
      padding: const EdgeInsets.all(SaffSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: SaffSpacing.xs),
          if (p.type != ProposalType.alarmDelete)
            Text(
              '$name · $time',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          if (days.isNotEmpty && p.type != ProposalType.alarmDelete)
            Text(
              days.length == 7
                  ? l10n.everyDay
                  : (days.toList()..sort())
                        .map((d) => _dayLabel(l10n, d))
                        .join(' '),
              style: TextStyle(color: c.muted),
            ),
          const SizedBox(height: SaffSpacing.sm),
          if (statusText != null)
            Text(statusText, style: TextStyle(color: c.muted))
          else if (p.isPending && mine && waiting.isNotEmpty)
            Text(
              l10n.waitingForAccept(waiting.join(', ')),
              style: TextStyle(color: c.muted),
            )
          else if (p.isPending && !isPair && p.requiredIds.isEmpty)
            Text(
              l10n.groupJoined(p.acceptedIds.length),
              style: TextStyle(color: c.muted),
            ),
          if (canVote || joinable) ...[
            const SizedBox(height: SaffSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('proposal-accept'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => vote(accept: true),
                    child: Text(joinable ? l10n.joinAlarm : l10n.accept),
                  ),
                ),
                if (canVote) ...[
                  const SizedBox(width: SaffSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => showProposeSheet(
                        context,
                        saffId: saffId,
                        supersedes: p.id,
                        initial: p.payload,
                        existing: p.type == ProposalType.alarmChange
                            ? ref
                                  .read(alarmsProvider(saffId))
                                  .value
                                  ?.where((a) => a.id == p.targetId)
                                  .firstOrNull
                            : null,
                      ),
                      child: Text(l10n.suggestOther),
                    ),
                  ),
                  const SizedBox(width: SaffSpacing.sm),
                  TextButton(
                    onPressed: () => vote(accept: false),
                    child: Text(l10n.no),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(AppLocalizations l10n, int d) => [
    l10n.dayMon,
    l10n.dayTue,
    l10n.dayWed,
    l10n.dayThu,
    l10n.dayFri,
    l10n.daySat,
    l10n.daySun,
  ][d - 1];
}
