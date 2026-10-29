import 'package:saff_app/data/services/firebase_services.dart';
import 'package:saff_domain/saff_domain.dart';

/// Server-computed stats, read-only (`docs/PRODUCT.md` §11).
abstract interface class StatsRepository {
  /// Stats of a saff with the calendar of [months] (`yyyyMM`), live.
  Stream<SaffStats> watchSaff(String saffId, List<String> months);

  /// The user's own counters and badges, live.
  Stream<PersonalStats> watchPersonal(String uid);
}

/// [StatsRepository] over Firestore.
final class StatsRepositoryImpl implements StatsRepository {
  /// Creates the repository.
  const StatsRepositoryImpl(this._fs);

  final FirestoreService _fs;

  Map<String, int> _ints(Object? v) => {
    for (final e in ((v as Map?) ?? const {}).entries)
      '${e.key}': (e.value as num).toInt(),
  };

  @override
  Stream<SaffStats> watchSaff(String saffId, List<String> months) {
    final col = _fs.db.collection('saffs/$saffId/stats');
    return col.snapshots().map((snap) {
      final byId = {for (final d in snap.docs) d.id: d.data()};
      final m = byId['summary'] ?? const <String, dynamic>{};
      final h2h = <String, HeadToHead>{
        for (final e in ((m['h2h'] as Map?) ?? const {}).entries)
          '${e.key}': HeadToHead(
            aWins: ((e.value as Map)['aWins'] as num?)?.toInt() ?? 0,
            bWins: ((e.value as Map)['bWins'] as num?)?.toInt() ?? 0,
            draws: ((e.value as Map)['draws'] as num?)?.toInt() ?? 0,
          ),
      };
      final days = <String, DayEntry>{};
      for (final month in months) {
        final d = byId['days_$month'];
        for (final e in ((d?['days'] as Map?) ?? const {}).entries) {
          final v = (e.value as Map).cast<String, dynamic>();
          days['${e.key}'] = DayEntry(
            date: '${e.key}',
            status: (v['status'] as String?) ?? 'grey',
            alarmName: (v['alarmName'] as String?) ?? '',
            winner: v['winner'] as String?,
            streak: (v['streak'] as num?)?.toInt() ?? 0,
            members: {
              for (final mm in ((v['members'] as Map?) ?? const {}).entries)
                '${mm.key}': DayMember(
                  woke: ((mm.value as Map)['woke'] as bool?) ?? false,
                  skipped: ((mm.value as Map)['skipped'] as bool?) ?? false,
                  points: ((mm.value as Map)['points'] as num?)?.toInt() ?? 0,
                  wakeMs: ((mm.value as Map)['wakeMs'] as num?)?.toInt(),
                ),
            },
          );
        }
      }
      return SaffStats(
        rounds: (m['rounds'] as num?)?.toInt() ?? 0,
        everyoneUp: (m['everyoneUp'] as num?)?.toInt() ?? 0,
        longestStreak: (m['longestStreak'] as num?)?.toInt() ?? 0,
        firstWaker: _ints(m['firstWaker']),
        headToHead: h2h,
        nudgesSent: _ints(m['nudgesSent']),
        nudgesReceived: _ints(m['nudgesReceived']),
        days: days,
      );
    });
  }

  @override
  Stream<PersonalStats> watchPersonal(String uid) {
    final stats = _fs.db.doc('users/$uid/stats/summary').snapshots();
    final badges = _fs.db.collection('users/$uid/badges').snapshots();
    return stats.asyncExpand(
      (s) => badges.map((b) {
        final m = s.data() ?? const <String, dynamic>{};
        int n(String k) => (m[k] as num?)?.toInt() ?? 0;
        return PersonalStats(
          streak: n('streak'),
          longestStreak: n('longestStreak'),
          rounds: n('rounds'),
          roundsWoke: n('roundsWoke'),
          lightning: n('lightning'),
          noSnooze: n('noSnooze'),
          wakeMsSum: n('wakeMsSum'),
          wakeCount: n('wakeCount'),
          badges: b.docs.map((d) => d.id).toSet(),
        );
      }),
    );
  }
}
