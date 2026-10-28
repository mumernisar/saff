# The alarm module (`packages/saff_alarm`)

The highest-risk part of the app. Built first (Stage 1) and changed only with the device checklist (§9).
Design follows proven open-source Android alarm apps (Fossify Clock, Yuriy Kulikov's Simple Alarm Clock)
and current Android guidance: single-fire `setAlarmClock()` alarms, rescheduled on every relevant event,
a foreground service for ringing, and a full-screen alarm activity.

---

## 1. Responsibilities

- Schedule exact alarms for upcoming occurrences (next 7 days) from absolute instants.
- Survive reboot, app update, time change, timezone change, and process death.
- Ring reliably: sound, vibration, volume ramp, over the lock screen, through silent/DND.
- Show the Flutter wake flow quickly, with a native fallback if Flutter fails.
- Re-ring on demand (nudge, idle guard), snooze once.
- Report readiness (permissions, battery optimisation) and diagnostics (ring log).

Not responsibilities: deciding *when* occurrences are (the app passes them in), anything networked.

---

## 2. Dart API (Pigeon)

```dart
@HostApi()
abstract class AlarmHostApi {
  /// Replaces the whole native schedule with [occurrences] (idempotent).
  void setSchedule(List<NativeOccurrence> occurrences);
  List<NativeOccurrence> getSchedule();
  void ringNow(RingReason reason, String? occurrenceId, String? message);  // nudge, idle, test
  void stopRinging(StopReason reason);                                     // started, snoozed, dismissed
  void snooze(int minutes);
  ReadinessReport getReadiness();               // permissions, battery, FSI, notification channel state
  void openSettings(ReadinessItem item);        // deep-links to the exact system screen
  void scheduleTestAlarm(int secondsFromNow);
  List<RingLogEntry> drainRingLog();
}

@FlutterApi()
abstract class AlarmFlutterApi {               // called on the wake engine
  void onRingStarted(String occurrenceId, int ringStartedElapsedMs, int rampMs);
  void onRingStopped(StopReason reason);
}

class NativeOccurrence { String id; int ringAtEpochMs; String alarmName; String? soundUri;
                         bool vibrate; int rampMs; String saffId; }
enum RingReason { scheduled, nudge, idle, snoozeEnd, test }
```
Pigeon errors use catalog codes (`ALARM_PERMISSION_MISSING`, `FULL_SCREEN_DENIED`, ...).

---

## 3. Android components

| Component | Role |
|---|---|
| `AlarmScheduler` | Computes the next occurrence and calls `AlarmManager.setAlarmClock(info, pendingIntent)`. Only the **next** alarm is set; on each fire, the following one is scheduled. Stores the full list in `SharedPreferences` (JSON) so it works without the app process. |
| `AlarmReceiver` | Receives the alarm broadcast; starts `RingingService` immediately (allowed: exact alarm exemption). Keeps work minimal. |
| `RingingService` | Foreground service. Acquires a partial wake lock (with timeout 10 min), plays sound on the **alarm** audio stream with `AudioAttributes.USAGE_ALARM`, ramps volume over `rampMs`, vibrates, posts the ongoing notification with a **full-screen intent** to `AlarmActivity`, pre-warms the Flutter engine for `wakeMain`. Stops on `stopRinging`, or after 30 min (auto-silence, logged). |
| `AlarmActivity` | `FlutterActivity` subclass using the pre-warmed engine (cached engine id), `showWhenLocked` + `turnScreenOn`. If the engine isn't ready within 5 s or reports a crash, switches to `NativeFallbackFragment`. |
| `NativeFallbackFragment` | Plain native screen: time, alarm name, "Stop alarm" (hold), "Open Saff". Used only when Flutter fails. |
| `RescheduleReceiver` | `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED` (direct boot), `MY_PACKAGE_REPLACED`, `TIME_SET`, `TIMEZONE_CHANGED`, `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` → reschedule from stored list. |
| `RingLog` | Append-only local log (fired at, delay vs scheduled, engine start ms, fallback used, errors). Drained to Dart and uploaded as diagnostics. |

Direct boot: store the schedule in device-protected storage so alarms ring after a reboot before the
first unlock.

---

## 4. Permissions and Play declarations

| Permission | Why | Notes |
|---|---|---|
| `USE_EXACT_ALARM` | Exact alarms without user toggling (alarm-clock apps) | Requires the Play Console declaration as an alarm app |
| `SCHEDULE_EXACT_ALARM` (maxSdk 32) | Android 12 devices | |
| `USE_FULL_SCREEN_INTENT` | Alarm screen over lock screen | Play declaration (alarm use case); check `canUseFullScreenIntent()` on Android 14+ |
| `POST_NOTIFICATIONS` | Ongoing ring notification, pushes | Runtime permission (Android 13+) |
| `FOREGROUND_SERVICE` + type permission | `RingingService` | Use the `systemExempted` type, which Android documents for apps holding exact-alarm permission that run a foreground service to continue an alarm; fall back to `mediaPlayback` if review requires. **Verify against current Android and Play policy in Stage 1.** |
| `WAKE_LOCK`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` | | |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prompt to exempt the app | Policy-sensitive; acceptable for alarm apps; justify in the Play declaration |

Readiness checks (`getReadiness`) run on every app start; missing items show the fix banner.

---

## 5. The ring path (sequence)

```
AlarmManager fires ─► AlarmReceiver.onReceive
   └► startForegroundService(RingingService, occurrenceId)            t ≈ 0 ms
        ├► startForeground(notification with fullScreenIntent)        t < 100 ms
        ├► start sound (alarm stream, ramp) + vibration               t < 300 ms
        ├► schedule next occurrence (AlarmScheduler)                  
        ├► pre-warm FlutterEngine(wakeMain) if not cached             
        └► launch AlarmActivity (via full-screen intent / startActivity when allowed)
AlarmActivity ─► attach cached engine ─► Dart wakeMain reads locked round from Drift
   └► AlarmFlutterApi.onRingStarted(...)                              t ≈ 1 s
       fallback: engine not ready in 5 s → NativeFallbackFragment
User holds Start ─► Dart calls stopRinging(started) ─► service stops sound, keeps a quiet
   foreground notification while the round is in progress (idle guard can re-ring)
```

- Every step after "start sound" is wrapped so its failure can't stop the sound.
- Custom sound fails to load → default alarm tone. Vibrator missing → skip.
- If the device is in a call: ring at reduced volume with vibration (system behaviour for alarm stream).

---

## 6. Snooze, idle guard, nudges

- **Snooze:** `snooze(5)` stops sound, schedules a one-off `snoozeEnd` alarm via `setAlarmClock`, records it.
- **Idle guard:** the Dart wake flow calls `ringNow(idle)` after 60 s without input; Continue stops it.
- **Nudge:** the FCM background handler (Dart) receives `type: nudge` and calls `ringNow(nudge, ...)`,
  which starts `RingingService` with the message "Ali rang you again". If the member already finished
  the round (`done`), ignore. Background start of the foreground service from a high-priority FCM
  message is permitted; verify on all test devices (§9).

---

## 7. Battery and OEM handling

- Onboarding asks to exempt the app from battery optimisation and shows brand-specific steps for Xiaomi
  (MIUI/HyperOS autostart + battery saver), Samsung (sleeping apps), Oppo/Realme/OnePlus (ColorOS
  auto-launch), Vivo (background power), Huawei, others. Steps are stored as data in the app
  (`oem_guides.json`) so they can be updated without code changes.
- The test alarm (10 s, phone locked) confirms the result; failures route to troubleshooting.

---

## 8. iOS (later, AlarmKit, iOS 26+)

- Same Dart API; Swift implementation schedules AlarmKit alarms for each occurrence and opens the app's
  wake flow when the user interacts. Nudges on iOS use a time-sensitive push that opens the wake flow
  (AlarmKit cannot be triggered remotely; confirm at implementation).
- iOS is out of scope for now (owner decision); nothing Android-specific may leak into the Dart API.

---

## 9. Device checklist (run for every change to this package)

Devices: at least one each of Samsung (One UI), Xiaomi (HyperOS/MIUI), Oppo/Realme/Vivo, and a Pixel or
stock Android emulator on the latest API level. Record results in the stage file.

| # | Scenario | Pass |
|---|---|---|
| 1 | App in foreground, alarm at T+2 min | Rings within 5 s of the minute |
| 2 | App swiped away, screen locked, 30 min idle | Rings, full screen over lock screen |
| 3 | Battery saver on, device idle overnight (Doze) | Rings on time |
| 4 | Reboot, don't unlock | Rings (direct boot) |
| 5 | Update the app between scheduling and ringing | Rings |
| 6 | Change timezone / time manually | Reschedules correctly |
| 7 | Silent mode and DND on | Rings on alarm stream |
| 8 | Flutter engine forced to fail (debug flag) | Native fallback appears; can stop alarm |
| 9 | Nudge from another device while locked | Re-rings within 10 s of the push |
| 10 | Snooze, then lock | Rings again after 5 min |
| 11 | Exact-alarm or full-screen permission revoked | Readiness banner appears; alarms rescheduled when restored |
| 12 | Airplane mode overnight | Rings; round plays from cache or arcade fallback |
