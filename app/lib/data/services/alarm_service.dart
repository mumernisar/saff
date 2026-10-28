import 'package:saff_alarm/saff_alarm.dart';

/// Wraps the native alarm module (`saff_alarm`). May throw; repositories map.
class AlarmService {
  /// Creates the service over [api].
  AlarmService([AlarmHostApi? api]) : _api = api ?? AlarmHostApi();

  final AlarmHostApi _api;

  /// Replaces the native schedule.
  Future<void> setSchedule(List<NativeOccurrence> occurrences) =>
      _api.setSchedule(occurrences);

  /// The native schedule as stored.
  Future<List<NativeOccurrence>> getSchedule() => _api.getSchedule();

  /// Rings now for [reason].
  Future<void> ringNow(RingReason reason, {String? id, String? message}) =>
      _api.ringNow(reason, id, message);

  /// Stops the ring.
  Future<void> stopRinging(StopReason reason) => _api.stopRinging(reason);

  /// Snoozes for [minutes].
  Future<void> snooze(int minutes) => _api.snooze(minutes);

  /// Permissions and battery state.
  Future<ReadinessReport> getReadiness() => _api.getReadiness();

  /// Opens the system screen for [item].
  Future<void> openSettings(ReadinessItem item) => _api.openSettings(item);

  /// Schedules a test alarm [seconds] from now.
  Future<void> scheduleTestAlarm(int seconds) =>
      _api.scheduleTestAlarm(seconds);

  /// Takes and clears the ring log.
  Future<List<RingLogEntry>> drainRingLog() => _api.drainRingLog();

  /// The ring in progress.
  Future<ActiveRing?> getActiveRing() => _api.getActiveRing();

  /// Tells native the wake UI is on screen.
  Future<void> reportWakeReady() => _api.reportWakeReady();
}
