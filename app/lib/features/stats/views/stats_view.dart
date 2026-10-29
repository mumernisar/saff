import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/stats/widgets/badges_grid.dart';
import 'package:saff_app/features/stats/widgets/month_calendar.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// Which scope the Stats tab shows: the user, or one saff.
class StatsScope extends Notifier<String?> {
  @override
  String? build() => null;

  /// Null shows the personal view.
  // ignore: use_setters_to_change_properties
  void set(String? saffId) => state = saffId;
}

/// Provider of the selected scope.
final statsScopeProvider = NotifierProvider<StatsScope, String?>(
  StatsScope.new,
);

/// The Stats tab (`docs/design/flows.md` frames 8a-8h).
class StatsView extends ConsumerWidget {
  /// Creates the view.
  const StatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
    final scope = ref.watch(statsScopeProvider);
    final saff = saffs.where((s) => s.id == scope).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStats)),
      body: saffs.isEmpty
          ? EmptyState(
              title: l10n.statsEmptyTitle,
              message: l10n.statsEmptyBody,
              icon: Icons.bar_chart,
              action: PrimaryButton(
                label: l10n.startSaff,
                onPressed: () => context.push('/saff/new'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: SaffSpacing.xxl),
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SaffSpacing.lg,
                      vertical: SaffSpacing.sm,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: SaffSpacing.sm),
                        child: SaffChip(
                          label: l10n.you,
                          selected: saff == null,
                          onTap: () =>
                              ref.read(statsScopeProvider.notifier).set(null),
                        ),
                      ),
                      for (final s in saffs)
                        Padding(
                          padding: const EdgeInsets.only(right: SaffSpacing.sm),
                          child: SaffChip(
                            label: s.name,
                            selected: saff?.id == s.id,
                            onTap: () =>
                                ref.read(statsScopeProvider.notifier).set(s.id),
                          ),
                        ),
                    ],
                  ),
                ),
                if (saff == null) const _PersonalStats() else _SaffStats(saff),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SaffCard(
    padding: const EdgeInsets.all(SaffSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        Text(label, style: TextStyle(color: context.saff.muted)),
      ],
    ),
  );
}

class _Tiles extends StatelessWidget {
  const _Tiles(this.tiles);

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SaffSpacing.lg),
    child: GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SaffSpacing.md,
      crossAxisSpacing: SaffSpacing.md,
      childAspectRatio: 1.9,
      children: tiles,
    ),
  );
}

class _PersonalStats extends ConsumerWidget {
  const _PersonalStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(personalStatsProvider).value ?? const PersonalStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tiles([
          _Tile('${s.streak}', l10n.statDaysInARow),
          _Tile('${s.longestStreak}', l10n.statBestStreak),
          _Tile(
            s.wakeCount == 0 ? '–' : '${s.avgWakeSeconds}s',
            l10n.statAvgWake,
          ),
          _Tile(s.rounds == 0 ? '–' : '${s.madePercent}%', l10n.statAlarmsMade),
        ]),
        SectionHeader(l10n.badges),
        BadgesGrid(stats: s),
      ],
    );
  }
}

class _SaffStats extends ConsumerWidget {
  const _SaffStats(this.saff);

  final Saff saff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(uidProvider).value ?? '';
    final stats =
        ref.watch(saffStatsProvider(saff.id)).value ?? const SaffStats();
    final members = ref.watch(membersProvider(saff.id)).value ?? const [];
    final others = members.where((m) => m.uid != uid).toList();
    final freeDays = ref
        .watch(environmentConfigProvider)
        .constants
        .statsHistoryFreeDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tiles([
          _Tile('${saff.streak}', l10n.statDayStreak),
          _Tile('${stats.longestStreak}', l10n.statLongest),
          _Tile(
            stats.rounds == 0 ? '–' : '${stats.successPercent}%',
            l10n.statEveryoneUp,
          ),
          _Tile('${stats.rounds}', l10n.statRoundsPlayed),
        ]),
        SectionHeader(l10n.calendar),
        MonthCalendar(
          stats: stats,
          members: members,
          meUid: uid,
          freeDays: freeDays,
        ),
        if (others.isNotEmpty) SectionHeader(l10n.standings),
        for (final m in others)
          Builder(
            builder: (_) {
              final v = stats.versus(uid, m.uid);
              final recv = stats.nudgesReceived[uid] ?? 0;
              return ListTile(
                leading: SaffAvatar(
                  name: m.displayName,
                  colorIndex: m.avatarColor,
                ),
                title: Text(m.displayName),
                subtitle: Text(
                  l10n.headToHeadLine(v.wins, v.draws, v.losses),
                ),
                trailing: recv > 0 && others.length == 1
                    ? Text(l10n.nudgedYou(recv))
                    : null,
              );
            },
          ),
        if (stats.firstWaker.isNotEmpty) ...[
          SectionHeader(l10n.firstWaker),
          for (final m in members)
            if ((stats.firstWaker[m.uid] ?? 0) > 0)
              ListTile(
                dense: true,
                title: Text(m.displayName),
                trailing: Text('${stats.firstWaker[m.uid]}'),
              ),
        ],
      ],
    );
  }
}
