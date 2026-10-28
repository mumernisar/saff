import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_core/saff_core.dart';

/// State of the alarm reliability screen.
class ReliabilityState {
  /// Creates the state.
  const ReliabilityState({this.readiness, this.log = const [], this.failure});

  /// Permission and battery state.
  final ReadinessReport? readiness;

  /// Latest ring log entries.
  final List<RingLogEntry> log;

  /// The last failure, for the error banner.
  final AppFailure? failure;
}

/// Loads readiness and the ring log, runs test alarms.
class ReliabilityViewModel extends AsyncNotifier<ReliabilityState> {
  @override
  Future<ReliabilityState> build() => _load(const []);

  Future<ReliabilityState> _load(List<RingLogEntry> keep) async {
    final repo = ref.read(alarmRepositoryProvider);
    final readiness = await repo.readiness();
    final drained = await repo.drainRingLog();
    final log = [...drained.getOrNull() ?? const <RingLogEntry>[], ...keep];
    return ReliabilityState(
      readiness: readiness.getOrNull(),
      log: log,
      failure: switch (readiness) {
        Err(:final failure) => failure,
        _ => null,
      },
    );
  }

  /// Re-reads everything (after returning from system settings).
  Future<void> refresh() async {
    final keep = state.value?.log ?? const <RingLogEntry>[];
    state = AsyncData(await _load(keep));
  }

  /// Opens the system screen for [item].
  Future<void> fix(ReadinessItem item) =>
      ref.read(alarmRepositoryProvider).openSettings(item);

  /// Rings the real alarm in 10 s.
  Future<void> scheduleTest() =>
      ref.read(alarmRepositoryProvider).scheduleTest(10);

  /// Rings immediately.
  Future<void> ringNow() =>
      ref.read(alarmRepositoryProvider).ringNow(RingReason.test);

  /// Sets or clears the debug flag that forces the native fallback.
  Future<void> setForceFallback({required bool on}) => ref
      .read(alarmRepositoryProvider)
      .ringNow(
        RingReason.test,
        message: on ? 'force-fallback' : 'clear-fallback',
      );
}

/// Provider of [ReliabilityViewModel].
final reliabilityProvider =
    AsyncNotifierProvider<ReliabilityViewModel, ReliabilityState>(
      ReliabilityViewModel.new,
    );
