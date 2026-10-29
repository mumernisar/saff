import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/saff/view_models/selected_saff.dart';
import 'package:saff_app/features/today/view_models/emulator_status_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/format.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// The Today tab: the next alarm across saffs, tonight's actions and the
/// user's saffs (`docs/design/flows.md` frames 5a–5f).
class TodayView extends ConsumerWidget {
  /// Creates the view.
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
    final loading = ref.watch(mySaffsProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabToday),
        actions: [
          IconButton(
            key: const ValueKey('open-settings'),
            icon: SaffAvatar(
              name: profile?.displayName ?? '',
              colorIndex: profile?.avatarColor ?? 0,
              size: 32,
            ),
            onPressed: () => context.go('/today/settings'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : saffs.isEmpty
          ? EmptyState(
              title: l10n.todayEmptyTitle,
              message: l10n.todayEmptyBody,
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: l10n.startSaff,
                    onPressed: () => context.push('/saff/new'),
                  ),
                  const SizedBox(height: SaffSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.push('/saff/join'),
                    child: Text(l10n.haveInvite),
                  ),
                ],
              ),
            )
          : _TodayBody(saffs: saffs),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.saffs});

  final List<Saff> saffs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final upcoming = ref.watch(myUpcomingProvider);
    final status = ref.watch(emulatorStatusProvider).value;
    final now = DateTime.now().toUtc();
    final live = upcoming
        .where(
          (o) =>
              o.status == 'locked' &&
              now.isAfter(o.ringAt.subtract(const Duration(minutes: 5))) &&
              now.isBefore(o.deadlineAt),
        )
        .toList();
    final next = upcoming.where((o) => o.ringAt.isAfter(now)).firstOrNull;
    return ListView(
      padding: const EdgeInsets.only(bottom: SaffSpacing.xxl),
      children: [
        if (status != null && status.any((r) => !r.reachable))
          DeviceFixBanner(
            message: l10n.emulatorsUnreachable,
            actionLabel: l10n.emulatorsRecheck,
            onFix: () => ref.read(emulatorStatusProvider.notifier).recheck(),
          ),
        for (final o in live)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SaffSpacing.lg,
              SaffSpacing.lg,
              SaffSpacing.lg,
              0,
            ),
            child: SaffCard(
              color: context.saff.soft,
              onTap: () => context.push('/wake/${o.saffId}/${o.id}'),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill, size: 32),
                  const SizedBox(width: SaffSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.roundInProgress(o.alarmName),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(SaffSpacing.lg),
          child: next == null
              ? SaffCard(child: Text(l10n.noUpcomingAlarm))
              : _NextAlarmCard(occurrence: next, saffs: saffs),
        ),
        SectionHeader(l10n.yourSaffs),
        for (final s in saffs)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SaffSpacing.lg,
              vertical: SaffSpacing.xs,
            ),
            child: _SaffTile(saff: s),
          ),
        Padding(
          padding: const EdgeInsets.all(SaffSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/saff/new'),
                  child: Text(l10n.newSaff),
                ),
              ),
              const SizedBox(width: SaffSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/saff/join'),
                  child: Text(l10n.haveInvite),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextAlarmCard extends ConsumerWidget {
  const _NextAlarmCard({required this.occurrence, required this.saffs});

  final Occurrence occurrence;
  final List<Saff> saffs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final saff = saffs.firstWhere(
      (s) => s.id == occurrence.saffId,
      orElse: () => saffs.first,
    );
    final members = ref.watch(membersProvider(saff.id)).value ?? const [];
    final left = occurrence.ringAt.difference(DateTime.now().toUtc());
    return SaffCard(
      onTap: () {
        ref.read(selectedSaffIdProvider.notifier).select(saff.id);
        context.go('/chat/${saff.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nextAlarm,
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SaffSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                clock(occurrence.ringAt),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: SaffSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${occurrence.alarmName} · ${weekday(occurrence.ringAt)}',
                    style: TextStyle(color: c.muted, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SaffSpacing.xs),
          Text(
            untilText(l10n, left),
            style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SaffSpacing.md),
          Row(
            children: [
              for (final m in members.where(
                (m) => occurrence.participantIds.contains(m.uid),
              ))
                Padding(
                  padding: const EdgeInsets.only(right: SaffSpacing.xs),
                  child: SaffAvatar(
                    name: m.displayName,
                    colorIndex: m.avatarColor,
                    size: 32,
                  ),
                ),
              const Spacer(),
              Text(
                l10n.streakDays(saff.streak),
                style: TextStyle(color: c.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaffTile extends ConsumerWidget {
  const _SaffTile({required this.saff});

  final Saff saff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(membersProvider(saff.id)).value ?? const [];
    return SaffCard(
      onTap: () => context.push('/saff/${saff.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saff.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  saff.memberCount < 2
                      ? l10n.waitingForSomeone
                      : l10n.memberCount(saff.memberCount),
                  style: TextStyle(color: context.saff.muted),
                ),
              ],
            ),
          ),
          for (final m in members.take(4))
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: SaffAvatar(
                name: m.displayName,
                colorIndex: m.avatarColor,
                size: 28,
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
