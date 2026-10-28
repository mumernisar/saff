# Stage 01: Alarm module

Branch: `stage/00-foundations` (continued; the owner asked for the whole build without stage pauses) · Started: 2026-10-29

## 1. Starting point
`saff_alarm` was a plugin shell; the app had four placeholder tabs and no wake entrypoint.

## 2. Plan
Pigeon API → native scheduler/receiver/service/activity/fallback/reschedule/log → Dart service + repository → `wakeMain` placeholder ring screen → reliability screen (readiness, test alarm, ring log).

## 3. What was done
- Pigeon API (`packages/saff_alarm/pigeons/alarm_api.dart`) with the `ALARM.md` §2 surface plus `getActiveRing` and `reportWakeReady` (the wake engine pulls the ring on start; `AlarmFlutterApi` pushes later rings, e.g. nudges).
- Kotlin: `AlarmScheduler` (one `setAlarmClock` for the next occurrence), `AlarmReceiver`, `RingingService` (alarm-stream sound with ramp, vibration, FSI notification, wake lock, 30-min auto-silence, engine pre-warm), `AlarmActivity` (cached engine, over lock screen, 5 s timeout), `NativeFallbackActivity`, `RescheduleReceiver`, `ScheduleStore` in device-protected storage, ring log.
- App: `AlarmService`/`AlarmRepository`, `AlarmFailureMapper`, `wake_main.dart`, `RingingView` with hold-to-start and one snooze, Settings → Alarm reliability screen.

## 4. Decisions
- **Native fallback is an Activity, not a Fragment** (`ALARM.md` §3 says Fragment). Alternatives: Fragment inside `AlarmActivity`. Why: a separate activity still works when the Flutter activity's engine attach itself fails.
- **`androidx.core` added to `saff_alarm`** (`ContextCompat.startForegroundService`); Apache-2.0, Google-maintained.
- Debug switch for checklist #8: `ringNow(test, message: 'force-fallback')` sets a flag that skips the Flutter engine; `clear-fallback` resets it. It lives in the dev reliability screen only.
- `wake_main.dart` is imported (unused) from both `main_*.dart` so the Dart library is in the kernel for `executeDartEntrypoint` by name.

## 5. Evidence (Samsung S23, One UI, Android 14+)
- #1/#2 partly: ring now over the lock screen, wake engine showed `RingingView`, hold-to-start stopped the sound and showed "Round started" (screenshots taken during the session).
- #8: forced engine failure showed the native fallback over the lock screen.
- Not done: Xiaomi / Oppo / Pixel devices, reboot/direct-boot, Doze overnight, timezone change, update-while-scheduled, permission-revoked rows. No other phones are available; these rows remain open for the owner.
- Ring-log timings visible in Settings → Alarm reliability (sound start / wake time), not yet measured against the < 500 ms / < 1.5 s targets on a mid-range device.

## 6. Deviations
Exit criteria "3 OEMs + stock" and "Play declarations drafted" are not met (see §5).

## 7. Known issues / follow-ups
- Runtime `POST_NOTIFICATIONS` request: the "Fix" button opens notification settings; a real runtime prompt comes with onboarding.
- Ring screen is a placeholder until the design system (Stage 2) and the wake flow (Stage 6).
