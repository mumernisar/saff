import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_domain/saff_domain.dart';

/// State of the ringing screen.
class RingingState {
  /// Creates the state.
  const RingingState({this.ring, this.snoozed = false, this.started = false});

  /// The ring in progress; null when none.
  final ActiveRing? ring;

  /// Whether the single snooze was used.
  final bool snoozed;

  /// Whether the member started the round.
  final bool started;

  /// A copy with changes.
  RingingState copyWith({
    ActiveRing? ring,
    bool? snoozed,
    bool? started,
    bool clearRing = false,
  }) => RingingState(
    ring: clearRing ? null : (ring ?? this.ring),
    snoozed: snoozed ?? this.snoozed,
    started: started ?? this.started,
  );
}

/// Drives the ringing screen: loads the active ring, reacts to native events.
class RingingViewModel extends Notifier<RingingState>
    implements AlarmFlutterApi {
  @override
  RingingState build() {
    AlarmFlutterApi.setUp(this);
    ref.onDispose(() => AlarmFlutterApi.setUp(null));
    return const RingingState();
  }

  DateTime _loadedAt = DateTime.now();

  /// Reads the ring that woke this engine.
  Future<void> load() async {
    final result = await ref.read(alarmRepositoryProvider).activeRing();
    final ring = result.getOrNull();
    if (ring != null) {
      _loadedAt = DateTime.now();
      state = state.copyWith(
        ring: ring,
        started: false,
        snoozed: ring.occurrenceId.startsWith('snooze:'),
      );
      unawaited(_status(LiveStatus.asleep));
    }
  }

  Future<void> _status(LiveStatus s) async {
    final ring = state.ring;
    final uid = ref.read(authRepositoryProvider).currentUid;
    if (ring == null || uid == null || ring.saffId.isEmpty) return;
    final occ = realOccurrenceId(ring.occurrenceId);
    if (occ == null) return;
    await ref.read(roundRepositoryProvider).setStatus(ring.saffId, occ, uid, s);
  }

  /// Called after the hold completes: stops the sound and hands over to the
  /// wake flow with how long the alarm has been ringing.
  Future<void> start() async {
    final ring = state.ring;
    final ageMs = ring == null
        ? 0
        : (ring.nowElapsedMs - ring.ringStartedElapsedMs) +
              DateTime.now().difference(_loadedAt).inMilliseconds;
    ref
        .read(wakeContextProvider.notifier)
        .set(
          WakeContext(
            ringAgeMs: ageMs,
            snoozed: state.snoozed,
            saffId: ring?.saffId ?? '',
            occurrenceId: realOccurrenceId(ring?.occurrenceId ?? ''),
          ),
        );
    await ref.read(alarmRepositoryProvider).stop(StopReason.started);
    state = state.copyWith(started: true);
  }

  /// Snoozes once.
  Future<void> snooze(int minutes) async {
    if (state.snoozed) return;
    unawaited(_status(LiveStatus.snoozed));
    await ref.read(alarmRepositoryProvider).snooze(minutes);
    state = state.copyWith(snoozed: true, clearRing: true);
  }

  @override
  void onRingStarted(ActiveRing ring) {
    state = state.copyWith(ring: ring, started: false);
  }

  @override
  void onRingStopped(StopReason reason) {
    if (reason == StopReason.snoozed || reason == StopReason.dismissed) {
      state = state.copyWith(clearRing: true);
    }
  }
}

/// Provider of the ringing view model.
final ringingProvider = NotifierProvider<RingingViewModel, RingingState>(
  RingingViewModel.new,
);

/// The real occurrence id of a ring, or null for test and manual rings.
String? realOccurrenceId(String ringId) {
  final id = ringId.startsWith('snooze:') ? ringId.substring(7) : ringId;
  if (id.isEmpty || id.startsWith('test:') || id == 'manual') return null;
  return id;
}

/// What the ringing screen hands to the wake flow.
class WakeContext {
  /// Creates the context.
  const WakeContext({
    this.ringAgeMs,
    this.snoozed = false,
    this.saffId = '',
    this.occurrenceId,
  });

  /// How long the alarm had been ringing when the member started.
  final int? ringAgeMs;

  /// Whether the member snoozed first.
  final bool snoozed;

  /// Saff of the ring.
  final String saffId;

  /// Occurrence of the ring; null for test rings.
  final String? occurrenceId;
}

/// Holder of the latest [WakeContext].
class WakeContextNotifier extends Notifier<WakeContext> {
  @override
  WakeContext build() => const WakeContext();

  /// Replaces the context.
  // ignore: use_setters_to_change_properties
  void set(WakeContext c) => state = c;
}

/// Provider of [WakeContext].
final wakeContextProvider = NotifierProvider<WakeContextNotifier, WakeContext>(
  WakeContextNotifier.new,
);
