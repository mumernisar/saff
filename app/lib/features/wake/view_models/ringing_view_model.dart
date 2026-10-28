import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';

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

  /// Reads the ring that woke this engine.
  Future<void> load() async {
    final result = await ref.read(alarmRepositoryProvider).activeRing();
    final ring = result.getOrNull();
    if (ring != null) state = state.copyWith(ring: ring, started: false);
  }

  /// Called after the hold completes.
  Future<void> start() async {
    await ref.read(alarmRepositoryProvider).stop(StopReason.started);
    state = state.copyWith(started: true);
  }

  /// Snoozes once.
  Future<void> snooze(int minutes) async {
    if (state.snoozed) return;
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
