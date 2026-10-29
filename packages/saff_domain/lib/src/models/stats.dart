/// One calendar day of a saff (`docs/design/flows.md` frames 8d-8f).
final class DayEntry {
  /// Creates an entry.
  const DayEntry({
    required this.date,
    required this.status,
    required this.alarmName,
    required this.members,
    this.winner,
    this.streak = 0,
  });

  /// `yyyyMMdd`.
  final String date;

  /// `green`, `red` or `grey`.
  final String status;

  /// Alarm that day.
  final String alarmName;

  /// uid → outcome.
  final Map<String, DayMember> members;

  /// uid of the winner, if ranked.
  final String? winner;

  /// Saff streak after that day.
  final int streak;
}

/// One member's outcome on a day.
final class DayMember {
  /// Creates an outcome.
  const DayMember({
    required this.woke,
    required this.skipped,
    required this.points,
    this.wakeMs,
  });

  /// Whether the member woke.
  final bool woke;

  /// Whether the member skipped.
  final bool skipped;

  /// Points that morning.
  final int points;

  /// Wake time.
  final int? wakeMs;
}

/// Head-to-head between two members (a < b by uid).
final class HeadToHead {
  /// Creates the record.
  const HeadToHead({this.aWins = 0, this.bWins = 0, this.draws = 0});

  /// Wins of the lower uid.
  final int aWins;

  /// Wins of the higher uid.
  final int bWins;

  /// Draws.
  final int draws;
}

/// Stats of one saff.
final class SaffStats {
  /// Creates the stats.
  const SaffStats({
    this.rounds = 0,
    this.everyoneUp = 0,
    this.longestStreak = 0,
    this.firstWaker = const {},
    this.headToHead = const {},
    this.nudgesSent = const {},
    this.nudgesReceived = const {},
    this.days = const {},
  });

  /// Occurrences played (cancelled excluded).
  final int rounds;

  /// Occurrences where everyone woke.
  final int everyoneUp;

  /// Longest saff streak.
  final int longestStreak;

  /// uid → times first to wake.
  final Map<String, int> firstWaker;

  /// `a_b` → record.
  final Map<String, HeadToHead> headToHead;

  /// uid → nudges sent.
  final Map<String, int> nudgesSent;

  /// uid → nudges received.
  final Map<String, int> nudgesReceived;

  /// `yyyyMMdd` → day.
  final Map<String, DayEntry> days;

  /// Share of occurrences everyone woke, 0-100.
  int get successPercent =>
      rounds == 0 ? 0 : (everyoneUp * 100 / rounds).round();

  /// The record between [x] and [y] as seen from [x].
  ({int wins, int losses, int draws}) versus(String x, String y) {
    final a = x.compareTo(y) < 0 ? x : y;
    final b = x.compareTo(y) < 0 ? y : x;
    final h = headToHead['${a}_$b'] ?? const HeadToHead();
    return x == a
        ? (wins: h.aWins, losses: h.bWins, draws: h.draws)
        : (wins: h.bWins, losses: h.aWins, draws: h.draws);
  }
}

/// The user's own counters.
final class PersonalStats {
  /// Creates the counters.
  const PersonalStats({
    this.streak = 0,
    this.longestStreak = 0,
    this.rounds = 0,
    this.roundsWoke = 0,
    this.lightning = 0,
    this.noSnooze = 0,
    this.wakeMsSum = 0,
    this.wakeCount = 0,
    this.badges = const {},
  });

  /// Current streak across saffs.
  final int streak;

  /// Best streak.
  final int longestStreak;

  /// Occurrences taken part in.
  final int rounds;

  /// Occurrences woke.
  final int roundsWoke;

  /// Wakes within 15 s.
  final int lightning;

  /// Wakes without snoozing.
  final int noSnooze;

  /// Sum of wake times.
  final int wakeMsSum;

  /// Number of wake times.
  final int wakeCount;

  /// Earned badge ids.
  final Set<String> badges;

  /// Average wake time in seconds.
  int get avgWakeSeconds =>
      wakeCount == 0 ? 0 : (wakeMsSum / wakeCount / 1000).round();

  /// Share of occurrences the user woke.
  int get madePercent => rounds == 0 ? 0 : (roundsWoke * 100 / rounds).round();
}
