import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/alarm_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/app/saff/saff_alarm/AlarmApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.saff.saff_alarm'),
  ),
)
/// Why the alarm rings.
enum RingReason { scheduled, nudge, idle, snoozeEnd, test }

/// Why ringing stops.
enum StopReason { started, snoozed, dismissed }

/// Items of the readiness report that can be opened in system settings.
enum ReadinessItem {
  exactAlarm,
  fullScreenIntent,
  notifications,
  batteryOptimisation,
}

/// One alarm ring moment, passed from Dart to the native scheduler.
class NativeOccurrence {
  NativeOccurrence({
    required this.id,
    required this.ringAtEpochMs,
    required this.alarmName,
    required this.vibrate,
    required this.rampMs,
    required this.saffId,
    this.soundUri,
  });

  String id;
  int ringAtEpochMs;
  String alarmName;
  String? soundUri;
  bool vibrate;
  int rampMs;
  String saffId;
}

/// What the phone currently allows the alarm to do.
class ReadinessReport {
  ReadinessReport({
    required this.exactAlarmAllowed,
    required this.fullScreenIntentAllowed,
    required this.notificationsAllowed,
    required this.batteryOptimisationIgnored,
    required this.manufacturer,
  });

  bool exactAlarmAllowed;
  bool fullScreenIntentAllowed;
  bool notificationsAllowed;
  bool batteryOptimisationIgnored;
  String manufacturer;
}

/// One line of the local ring log.
class RingLogEntry {
  RingLogEntry({
    required this.occurrenceId,
    required this.firedAtEpochMs,
    required this.delayMs,
    required this.soundStartMs,
    required this.engineReadyMs,
    required this.usedFallback,
    this.error,
  });

  String occurrenceId;
  int firedAtEpochMs;
  int delayMs;
  int soundStartMs;
  int engineReadyMs;
  bool usedFallback;
  String? error;
}

/// The ring currently in progress, read by the wake engine on start.
class ActiveRing {
  ActiveRing({
    required this.occurrenceId,
    required this.alarmName,
    required this.saffId,
    required this.ringStartedElapsedMs,
    required this.rampMs,
    required this.reason,
  });

  String occurrenceId;
  String alarmName;
  String saffId;
  int ringStartedElapsedMs;
  int rampMs;
  RingReason reason;
}

@HostApi()
abstract class AlarmHostApi {
  /// Replaces the whole native schedule (idempotent).
  void setSchedule(List<NativeOccurrence> occurrences);

  List<NativeOccurrence> getSchedule();

  void ringNow(RingReason reason, String? occurrenceId, String? message);

  void stopRinging(StopReason reason);

  void snooze(int minutes);

  ReadinessReport getReadiness();

  void openSettings(ReadinessItem item);

  void scheduleTestAlarm(int secondsFromNow);

  List<RingLogEntry> drainRingLog();

  /// The ring in progress, or null when nothing is ringing.
  ActiveRing? getActiveRing();

  /// Called by the wake engine when its first frame is on screen.
  void reportWakeReady();
}

/// Called on the wake engine.
@FlutterApi()
abstract class AlarmFlutterApi {
  void onRingStarted(ActiveRing ring);

  void onRingStopped(StopReason reason);
}
