import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/data/services/alarm_service.dart';
import 'package:saff_core/saff_core.dart';

/// Native alarm state as seen by the UI layer.
abstract interface class AlarmRepository {
  /// Replaces the native schedule with [occurrences].
  Future<Result<void>> setSchedule(List<NativeOccurrence> occurrences);

  /// What is currently scheduled natively.
  Future<Result<List<NativeOccurrence>>> schedule();

  /// Permissions and battery state.
  Future<Result<ReadinessReport>> readiness();

  /// Opens the system settings screen for [item].
  Future<Result<void>> openSettings(ReadinessItem item);

  /// Rings in [seconds] seconds, for the test alarm.
  Future<Result<void>> scheduleTest(int seconds);

  /// Rings immediately.
  Future<Result<void>> ringNow(RingReason reason, {String? message});

  /// Takes and clears the ring log.
  Future<Result<List<RingLogEntry>>> drainRingLog();

  /// The ring in progress, if any.
  Future<Result<ActiveRing?>> activeRing();

  /// Stops the sound; [reason] says why.
  Future<Result<void>> stop(StopReason reason);

  /// Snoozes the current ring.
  Future<Result<void>> snooze(int minutes);

  /// Reports that the wake UI is up.
  Future<Result<void>> reportWakeReady();

  /// The device's IANA timezone.
  Future<Result<String>> timezone();
}

/// [AlarmRepository] over [AlarmService].
final class AlarmRepositoryImpl implements AlarmRepository {
  /// Creates the repository.
  const AlarmRepositoryImpl(this._service, this._mapper);

  final AlarmService _service;
  final FailureMapper _mapper;

  Future<Result<T>> _g<T>(String op, Future<T> Function() f) =>
      Result.guard(f, _mapper, context: {'op': op});

  @override
  Future<Result<void>> setSchedule(List<NativeOccurrence> o) =>
      _g('setSchedule', () => _service.setSchedule(o));

  @override
  Future<Result<List<NativeOccurrence>>> schedule() =>
      _g('getSchedule', _service.getSchedule);

  @override
  Future<Result<ReadinessReport>> readiness() =>
      _g('getReadiness', _service.getReadiness);

  @override
  Future<Result<void>> openSettings(ReadinessItem item) =>
      _g('openSettings', () => _service.openSettings(item));

  @override
  Future<Result<void>> scheduleTest(int seconds) =>
      _g('scheduleTest', () => _service.scheduleTestAlarm(seconds));

  @override
  Future<Result<void>> ringNow(RingReason reason, {String? message}) =>
      _g('ringNow', () => _service.ringNow(reason, message: message));

  @override
  Future<Result<List<RingLogEntry>>> drainRingLog() =>
      _g('drainRingLog', _service.drainRingLog);

  @override
  Future<Result<ActiveRing?>> activeRing() =>
      _g('activeRing', _service.getActiveRing);

  @override
  Future<Result<void>> stop(StopReason reason) =>
      _g('stopRinging', () => _service.stopRinging(reason));

  @override
  Future<Result<void>> snooze(int minutes) =>
      _g('snooze', () => _service.snooze(minutes));

  @override
  Future<Result<void>> reportWakeReady() =>
      _g('reportWakeReady', _service.reportWakeReady);

  @override
  Future<Result<String>> timezone() => _g('timezone', _service.getTimezone);
}
