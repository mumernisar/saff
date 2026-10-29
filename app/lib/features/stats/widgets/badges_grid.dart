import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// One badge's definition for the grid.
class _Badge {
  const _Badge(this.id, this.icon, this.progress, this.target);

  final String id;
  final IconData icon;
  final int Function(PersonalStats) progress;
  final int target;
}

final _badges = <_Badge>[
  _Badge('first_light', Icons.wb_twilight, (s) => s.roundsWoke, 1),
  _Badge('streak_7', Icons.local_fire_department, (s) => s.longestStreak, 7),
  _Badge('streak_30', Icons.calendar_month, (s) => s.longestStreak, 30),
  _Badge('streak_100', Icons.military_tech, (s) => s.longestStreak, 100),
  _Badge('lightning', Icons.bolt, (s) => s.lightning, 5),
  _Badge('zero_snooze', Icons.snooze, (s) => s.noSnooze, 30),
];

String _title(AppLocalizations l, String id) => switch (id) {
  'first_light' => l.badgeFirstLight,
  'streak_7' => l.badgeStreak7,
  'streak_30' => l.badgeStreak30,
  'streak_100' => l.badgeStreak100,
  'lightning' => l.badgeLightning,
  _ => l.badgeZeroSnooze,
};

String _how(AppLocalizations l, String id) => switch (id) {
  'first_light' => l.badgeFirstLightHow,
  'streak_7' => l.badgeStreak7How,
  'streak_30' => l.badgeStreak30How,
  'streak_100' => l.badgeStreak100How,
  'lightning' => l.badgeLightningHow,
  _ => l.badgeZeroSnoozeHow,
};

/// Badges with progress rings (frames 8a-8c).
class BadgesGrid extends StatelessWidget {
  /// Creates the grid.
  const BadgesGrid({required this.stats, super.key});

  /// The user's counters.
  final PersonalStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SaffSpacing.lg),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: SaffSpacing.md,
        crossAxisSpacing: SaffSpacing.md,
        childAspectRatio: 0.85,
        children: [
          for (final b in _badges)
            Builder(
              builder: (_) {
                final earned = stats.badges.contains(b.id);
                final p = (b.progress(stats) / b.target).clamp(0.0, 1.0);
                return InkWell(
                  borderRadius: BorderRadius.circular(SaffRadii.md),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(SaffSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _title(l10n, b.id),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: SaffSpacing.sm),
                            Text(_how(l10n, b.id)),
                            const SizedBox(height: SaffSpacing.md),
                            Text(
                              earned
                                  ? l10n.badgeEarned
                                  : l10n.badgeProgress(
                                      b.progress(stats).clamp(0, b.target),
                                      b.target,
                                    ),
                              style: TextStyle(color: c.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: earned ? 1 : p,
                              strokeWidth: 4,
                              color: c.accent,
                              backgroundColor: c.line,
                            ),
                          ),
                          Icon(b.icon, color: earned ? c.accent : c.muted),
                        ],
                      ),
                      const SizedBox(height: SaffSpacing.xs),
                      Text(
                        _title(l10n, b.id),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: earned ? c.text : c.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
