import 'package:intl/intl.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// `in 7h 12m`-style countdown text.
String untilText(AppLocalizations l10n, Duration d) {
  if (d.isNegative) return l10n.now;
  if (d.inMinutes < 1) return l10n.inLessThanAMinute;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h == 0 ? l10n.inMinutes(m) : l10n.inHoursMinutes(h, m);
}

/// `HH:mm` of a local time.
String clock(DateTime t) => DateFormat.Hm().format(t.toLocal());

/// `Thursday` for a local date.
String weekday(DateTime t) => DateFormat.EEEE().format(t.toLocal());

/// `yyyy-MM-dd HH:mm` for diagnostics.
String stamp(DateTime t) => DateFormat('d MMM HH:mm').format(t.toLocal());
