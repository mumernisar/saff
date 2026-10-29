import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_domain/saff_domain.dart';

/// Keeps the native alarm schedule equal to the user's upcoming occurrences
/// across all saffs (`docs/ARCHITECTURE.md` §5a). Watched from the app shell.
final scheduleSyncProvider = Provider<void>((ref) {
  final upcoming = ref.watch(myUpcomingProvider);
  final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
  final constants = ref.watch(environmentConfigProvider).constants;
  final now = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
  final occurrences = [
    for (final o in upcoming)
      if (o.status != 'cancelled' && o.ringAt.isAfter(now))
        NativeOccurrence(
          id: o.id,
          ringAtEpochMs: o.ringAt.millisecondsSinceEpoch,
          alarmName: o.alarmName,
          vibrate: true,
          rampMs: constants.rampDuration.inMilliseconds,
          saffId: o.saffId,
        ),
  ];
  // Never wipe the schedule just because the streams have not loaded yet.
  if (saffs.isEmpty && upcoming.isEmpty) return;
  unawaited(ref.read(alarmRepositoryProvider).setSchedule(occurrences));
});
