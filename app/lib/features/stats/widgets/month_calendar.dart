import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// A month grid: green = everyone woke, red = someone missed, grey =
/// cancelled or skipped; tap a day for the sheet (frames 8d, 8f).
class MonthCalendar extends StatefulWidget {
  /// Creates the calendar.
  const MonthCalendar({
    required this.stats,
    required this.members,
    required this.meUid,
    required this.freeDays,
    super.key,
  });

  /// Stats with the days.
  final SaffStats stats;

  /// Members, for names in the sheet.
  final List<Member> members;

  /// The viewer.
  final String meUid;

  /// Days of history shown on the free plan.
  final int freeDays;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String _key(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final first = DateTime(_month.year, _month.month);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = first.weekday - 1;
    final today = DateTime.now();
    final cutoff = today.subtract(Duration(days: widget.freeDays));
    Color colorOf(String? status) => switch (status) {
      'green' => c.done,
      'red' => c.error,
      'grey' => c.asleep,
      _ => Colors.transparent,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SaffSpacing.lg),
      child: SaffCard(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < offset; i++) const SizedBox.shrink(),
                for (var d = 1; d <= days; d++)
                  Builder(
                    builder: (_) {
                      final date = DateTime(_month.year, _month.month, d);
                      final hidden = date.isBefore(cutoff);
                      final entry = hidden
                          ? null
                          : widget.stats.days[_key(date)];
                      final isToday = DateUtils.isSameDay(date, today);
                      return GestureDetector(
                        onTap: entry == null
                            ? null
                            : () => _daySheet(context, entry),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colorOf(entry?.status),
                            shape: BoxShape.circle,
                            border: isToday
                                ? Border.all(color: c.text, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$d',
                            style: TextStyle(
                              color: entry == null
                                  ? (hidden ? c.line : c.muted)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: SaffSpacing.sm),
            Wrap(
              spacing: SaffSpacing.md,
              children: [
                _Legend(c.done, l10n.legendEveryoneUp),
                _Legend(c.error, l10n.legendMissed),
                _Legend(c.asleep, l10n.legendSkipped),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _daySheet(BuildContext context, DayEntry day) {
    final l10n = AppLocalizations.of(context);
    String name(String uid) => uid == widget.meUid
        ? l10n.you
        : widget.members.where((m) => m.uid == uid).firstOrNull?.displayName ??
              l10n.deletedUser;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SaffSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.alarmName} · ${day.date.substring(6)}/${day.date.substring(4, 6)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SaffSpacing.md),
              for (final e in day.members.entries)
                ListTile(
                  dense: true,
                  title: Text(name(e.key)),
                  subtitle: Text(
                    e.value.skipped
                        ? l10n.daySkipped
                        : e.value.woke
                        ? l10n.dayUp(
                            e.value.wakeMs == null
                                ? '–'
                                : '${(e.value.wakeMs! / 1000).round()}s',
                            e.value.points,
                          )
                        : l10n.dayDidNotWake,
                  ),
                  trailing: day.winner == e.key
                      ? const Icon(Icons.emoji_events)
                      : null,
                ),
              if (day.streak > 0) Text(l10n.streakDays(day.streak)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: context.saff.muted),
      ),
    ],
  );
}
